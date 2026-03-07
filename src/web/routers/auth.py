"""Authentication API routes."""

from __future__ import annotations

import hashlib
import hmac
import json
import secrets
import time
from typing import Optional
from urllib.parse import urlencode

import httpx
from dishka import AsyncContainer, Scope
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import JSONResponse, RedirectResponse
from loguru import logger

from src.core.config import AppConfig
from src.core.storage.key_builder import WebAuthKey
from src.core.utils.types import CreateUserInput
from src.infrastructure.database import UnitOfWork
from src.infrastructure.database.models.sql.oauth_account import OAuthAccount
from src.infrastructure.database.models.sql.web_credential import WebCredential
from src.infrastructure.redis.repository import RedisRepository
from src.services.referral import ReferralService
from src.services.settings import SettingsService
from src.services.user import UserService
from src.web.auth import (
    create_access_token,
    hash_password,
    validate_init_data,
    verify_password,
)
from src.web.dependencies import get_bot_token, get_secret
from src.web.schemas import LoginRequest, PasswordLoginRequest, RegisterRequest

router = APIRouter(prefix="/api/auth", tags=["auth"])

_OAUTH_STATE_COOKIE = "oauth_state"
_OAUTH_STATE_MAX_AGE = 600  # 10 minutes


def _synthetic_telegram_id(provider: str, provider_user_id: str) -> int:
    """Derive a unique synthetic telegram_id for non-Telegram OAuth users.

    Range: [10^15, 2·10^15 − 1] — safely above real Telegram IDs.
    """
    digest = hashlib.md5(f"{provider}:{provider_user_id}".encode()).hexdigest()
    return 10**15 + int(digest, 16) % 10**15


async def _ensure_oauth_user(
    container: AsyncContainer,
    provider: str,
    provider_user_id: str,
    display_name: str,
    email: Optional[str] = None,
) -> int:
    """Find or create a user for an OAuth login. Returns telegram_id."""
    async with container(scope=Scope.REQUEST) as req_container:
        uow: UnitOfWork = await req_container.get(UnitOfWork)
        existing_oauth = await uow.repository.oauth_accounts.get_by_provider(provider, provider_user_id)
        if existing_oauth:
            return existing_oauth.telegram_id

        tg_id = _synthetic_telegram_id(provider, provider_user_id)

        user_service: UserService = await req_container.get(UserService)
        existing_user = await user_service.get(telegram_id=tg_id)
        if existing_user is None:
            try:
                settings_service: SettingsService = await req_container.get(SettingsService)
                settings = await settings_service.get()
                user_input = CreateUserInput(
                    telegram_id=tg_id,
                    full_name=display_name,
                    username=None,
                    language_code=None,
                )
                await user_service.create(user_input, settings=settings)
                logger.info(f"Auto-created user {tg_id} via {provider} OAuth")
            except Exception as exc:
                logger.error(f"Failed to create OAuth user {tg_id} ({provider}): {exc}")
                raise

        # Re-open nested context for oauth_accounts save
        async with container(scope=Scope.REQUEST) as req_container2:
            uow2: UnitOfWork = await req_container2.get(UnitOfWork)
            account = OAuthAccount(
                provider=provider,
                provider_user_id=provider_user_id,
                telegram_id=tg_id,
                email=email,
                display_name=display_name,
            )
            await uow2.repository.oauth_accounts.create(account)
            await uow2.commit()

        return tg_id


@router.post("/tg")
async def auth_telegram(request: Request):
    """Authenticate via Telegram Mini App initData. Auto-registers new users."""
    body = await request.json()
    init_data = body.get("initData", "")
    bot_token = get_bot_token(request)

    parsed = validate_init_data(init_data, bot_token)
    if parsed is None:
        raise HTTPException(status_code=401, detail="Invalid initData")

    user_json = parsed.get("user")
    if not user_json:
        raise HTTPException(status_code=401, detail="No user in initData")

    try:
        user_obj = json.loads(user_json)
    except json.JSONDecodeError:
        raise HTTPException(status_code=401, detail="Invalid user JSON")

    telegram_id = user_obj.get("id")
    if not telegram_id:
        raise HTTPException(status_code=401, detail="No user id")

    container: AsyncContainer = request.app.state.dishka_container
    async with container(scope=Scope.REQUEST) as req_container:
        user_service: UserService = await req_container.get(UserService)
        existing = await user_service.get(telegram_id=telegram_id)
        if existing is None:
            try:
                settings_service: SettingsService = await req_container.get(SettingsService)
                settings = await settings_service.get()
                first_name = user_obj.get("first_name") or "User"
                last_name = user_obj.get("last_name")
                full_name = f"{first_name} {last_name}" if last_name else first_name
                user_input = CreateUserInput(
                    telegram_id=telegram_id,
                    full_name=full_name,
                    username=user_obj.get("username"),
                    language_code=user_obj.get("language_code"),
                )
                await user_service.create(user_input, settings=settings)
                logger.info(f"Auto-registered user {telegram_id} via Mini App initData")
            except Exception as exc:
                logger.warning(f"Auto-register failed for user {telegram_id}: {exc}")

    token = create_access_token(
        {"telegram_id": telegram_id, "source": "miniapp"},
        get_secret(request),
    )
    response = JSONResponse({"ok": True, "telegram_id": telegram_id})
    response.set_cookie("access_token", token, httponly=True, samesite="none", secure=True, max_age=86400)
    return response


@router.post("/tg-widget")
async def auth_telegram_widget(request: Request):
    """Authenticate via Telegram Login Widget. Validates hash and auto-registers."""
    body = await request.json()
    bot_token = get_bot_token(request)

    telegram_id = body.get("id")
    if not telegram_id:
        raise HTTPException(status_code=401, detail="Missing id")

    received_hash = body.get("hash", "")
    auth_date = body.get("auth_date", 0)

    # Validate auth_date — must be within last 24 hours
    if time.time() - int(auth_date) > 86400:
        raise HTTPException(status_code=401, detail="Auth data expired")

    # Build check string: sorted key=value pairs, excluding "hash"
    check_data = {k: v for k, v in body.items() if k != "hash"}
    check_string = "\n".join(f"{k}={check_data[k]}" for k in sorted(check_data))

    secret = hashlib.sha256(bot_token.encode()).digest()
    expected = hmac.new(secret, check_string.encode(), hashlib.sha256).hexdigest()

    if not hmac.compare_digest(expected, received_hash):
        raise HTTPException(status_code=401, detail="Invalid hash")

    container: AsyncContainer = request.app.state.dishka_container
    async with container(scope=Scope.REQUEST) as req_container:
        user_service: UserService = await req_container.get(UserService)
        existing = await user_service.get(telegram_id=telegram_id)
        if existing is None:
            try:
                settings_service: SettingsService = await req_container.get(SettingsService)
                settings = await settings_service.get()
                first_name = body.get("first_name") or "User"
                last_name = body.get("last_name")
                full_name = f"{first_name} {last_name}" if last_name else first_name
                user_input = CreateUserInput(
                    telegram_id=telegram_id,
                    full_name=full_name,
                    username=body.get("username"),
                    language_code=None,
                )
                await user_service.create(user_input, settings=settings)
                logger.info(f"Auto-registered user {telegram_id} via Telegram Widget")
            except Exception as exc:
                logger.warning(f"Auto-register failed for user {telegram_id} (widget): {exc}")

    token = create_access_token(
        {"telegram_id": telegram_id, "source": "widget"},
        get_secret(request),
    )
    response = JSONResponse({"ok": True, "telegram_id": telegram_id})
    response.set_cookie("access_token", token, httponly=True, samesite="lax", secure=True, max_age=86400 * 30)
    return response


@router.get("/oauth/google")
async def oauth_google_redirect(request: Request):
    """Redirect user to Google OAuth authorization page."""
    config: AppConfig = request.app.state.config
    client_id = config.google_client_id.get_secret_value()
    if not client_id:
        raise HTTPException(status_code=501, detail="Google OAuth не настроен")

    state = secrets.token_urlsafe(32)
    web_domain = config.effective_web_domain
    redirect_uri = f"https://{web_domain}/web/api/auth/oauth/google/callback"

    params = urlencode({
        "client_id": client_id,
        "redirect_uri": redirect_uri,
        "response_type": "code",
        "scope": "openid email profile",
        "state": state,
        "access_type": "online",
        "prompt": "select_account",
    })
    auth_url = f"https://accounts.google.com/o/oauth2/v2/auth?{params}"

    response = RedirectResponse(url=auth_url, status_code=302)
    response.set_cookie(
        _OAUTH_STATE_COOKIE, state,
        httponly=True, samesite="lax", secure=True, max_age=_OAUTH_STATE_MAX_AGE,
    )
    return response


@router.get("/oauth/google/callback")
async def oauth_google_callback(request: Request):
    """Handle Google OAuth callback: exchange code, find/create user, set JWT cookie."""
    config: AppConfig = request.app.state.config
    client_id = config.google_client_id.get_secret_value()
    client_secret = config.google_client_secret.get_secret_value()

    code = request.query_params.get("code")
    state = request.query_params.get("state")
    stored_state = request.cookies.get(_OAUTH_STATE_COOKIE)

    if not code or not state or not stored_state or not hmac.compare_digest(state, stored_state):
        raise HTTPException(status_code=400, detail="Invalid OAuth state")

    web_domain = config.effective_web_domain
    redirect_uri = f"https://{web_domain}/web/api/auth/oauth/google/callback"

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            token_resp = await client.post(
                "https://oauth2.googleapis.com/token",
                data={
                    "code": code,
                    "client_id": client_id,
                    "client_secret": client_secret,
                    "redirect_uri": redirect_uri,
                    "grant_type": "authorization_code",
                },
            )
            token_data = token_resp.json()
            access_token = token_data.get("access_token")
            if not access_token:
                logger.warning(f"Google token exchange failed: {token_data}")
                raise HTTPException(status_code=502, detail="Google auth failed")

            user_resp = await client.get(
                "https://www.googleapis.com/oauth2/v3/userinfo",
                headers={"Authorization": f"Bearer {access_token}"},
            )
            google_user = user_resp.json()
    except httpx.HTTPError as exc:
        logger.error(f"Google OAuth HTTP error: {exc}")
        raise HTTPException(status_code=502, detail="Google auth failed")

    provider_user_id = google_user.get("sub")
    if not provider_user_id:
        raise HTTPException(status_code=502, detail="Google did not return user id")

    name = google_user.get("name") or google_user.get("email", "Google User")
    email = google_user.get("email")

    container: AsyncContainer = request.app.state.dishka_container
    try:
        tg_id = await _ensure_oauth_user(container, "google", str(provider_user_id), name, email)
    except Exception as exc:
        logger.error(f"Failed to create/find Google user: {exc}")
        raise HTTPException(status_code=500, detail="Internal error")

    jwt_token = create_access_token(
        {"telegram_id": tg_id, "source": "google"},
        get_secret(request),
    )
    response = RedirectResponse(url="/site/dashboard", status_code=302)
    response.set_cookie("access_token", jwt_token, httponly=True, samesite="lax", secure=True, max_age=86400 * 30)
    response.delete_cookie(_OAUTH_STATE_COOKIE)
    return response


@router.get("/oauth/github")
async def oauth_github_redirect(request: Request):
    """Redirect user to GitHub OAuth authorization page."""
    config: AppConfig = request.app.state.config
    client_id = config.github_client_id.get_secret_value()
    if not client_id:
        raise HTTPException(status_code=501, detail="GitHub OAuth не настроен")

    state = secrets.token_urlsafe(32)
    web_domain = config.effective_web_domain
    redirect_uri = f"https://{web_domain}/web/api/auth/oauth/github/callback"

    params = urlencode({
        "client_id": client_id,
        "redirect_uri": redirect_uri,
        "scope": "user:email",
        "state": state,
    })
    auth_url = f"https://github.com/login/oauth/authorize?{params}"

    response = RedirectResponse(url=auth_url, status_code=302)
    response.set_cookie(
        _OAUTH_STATE_COOKIE, state,
        httponly=True, samesite="lax", secure=True, max_age=_OAUTH_STATE_MAX_AGE,
    )
    return response


@router.get("/oauth/github/callback")
async def oauth_github_callback(request: Request):
    """Handle GitHub OAuth callback: exchange code, find/create user, set JWT cookie."""
    config: AppConfig = request.app.state.config
    client_id = config.github_client_id.get_secret_value()
    client_secret = config.github_client_secret.get_secret_value()

    code = request.query_params.get("code")
    state = request.query_params.get("state")
    stored_state = request.cookies.get(_OAUTH_STATE_COOKIE)

    if not code or not state or not stored_state or not hmac.compare_digest(state, stored_state):
        raise HTTPException(status_code=400, detail="Invalid OAuth state")

    web_domain = config.effective_web_domain
    redirect_uri = f"https://{web_domain}/web/api/auth/oauth/github/callback"

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            token_resp = await client.post(
                "https://github.com/login/oauth/access_token",
                headers={"Accept": "application/json"},
                data={
                    "client_id": client_id,
                    "client_secret": client_secret,
                    "code": code,
                    "redirect_uri": redirect_uri,
                },
            )
            token_data = token_resp.json()
            access_token = token_data.get("access_token")
            if not access_token:
                logger.warning(f"GitHub token exchange failed: {token_data}")
                raise HTTPException(status_code=502, detail="GitHub auth failed")

            user_resp = await client.get(
                "https://api.github.com/user",
                headers={
                    "Authorization": f"Bearer {access_token}",
                    "Accept": "application/vnd.github.v3+json",
                },
            )
            github_user = user_resp.json()

            email = github_user.get("email")
            if not email:
                # Some users have private email — fetch from /user/emails
                emails_resp = await client.get(
                    "https://api.github.com/user/emails",
                    headers={
                        "Authorization": f"Bearer {access_token}",
                        "Accept": "application/vnd.github.v3+json",
                    },
                )
                emails = emails_resp.json()
                primary = next((e["email"] for e in emails if e.get("primary") and e.get("verified")), None)
                email = primary
    except httpx.HTTPError as exc:
        logger.error(f"GitHub OAuth HTTP error: {exc}")
        raise HTTPException(status_code=502, detail="GitHub auth failed")

    provider_user_id = github_user.get("id")
    if not provider_user_id:
        raise HTTPException(status_code=502, detail="GitHub did not return user id")

    name = github_user.get("name") or github_user.get("login") or "GitHub User"

    container: AsyncContainer = request.app.state.dishka_container
    try:
        tg_id = await _ensure_oauth_user(container, "github", str(provider_user_id), name, email)
    except Exception as exc:
        logger.error(f"Failed to create/find GitHub user: {exc}")
        raise HTTPException(status_code=500, detail="Internal error")

    jwt_token = create_access_token(
        {"telegram_id": tg_id, "source": "github"},
        get_secret(request),
    )
    response = RedirectResponse(url="/site/dashboard", status_code=302)
    response.set_cookie("access_token", jwt_token, httponly=True, samesite="lax", secure=True, max_age=86400 * 30)
    response.delete_cookie(_OAUTH_STATE_COOKIE)
    return response


@router.post("/check")
async def auth_check_telegram_id(request: Request, body: LoginRequest):
    """Authenticate via Telegram Mini App initData. Auto-registers new users."""
    body = await request.json()
    init_data = body.get("initData", "")
    bot_token = get_bot_token(request)

    parsed = validate_init_data(init_data, bot_token)
    if parsed is None:
        raise HTTPException(status_code=401, detail="Invalid initData")

    user_json = parsed.get("user")
    if not user_json:
        raise HTTPException(status_code=401, detail="No user in initData")

    try:
        user_obj = json.loads(user_json)
    except json.JSONDecodeError:
        raise HTTPException(status_code=401, detail="Invalid user JSON")

    telegram_id = user_obj.get("id")
    if not telegram_id:
        raise HTTPException(status_code=401, detail="No user id")

    # Auto-register user if they've never started the bot
    container: AsyncContainer = request.app.state.dishka_container
    async with container(scope=Scope.REQUEST) as req_container:
        user_service: UserService = await req_container.get(UserService)
        existing = await user_service.get(telegram_id=telegram_id)
        if existing is None:
            try:
                settings_service: SettingsService = await req_container.get(SettingsService)
                settings = await settings_service.get()
                first_name = user_obj.get("first_name") or "User"
                last_name = user_obj.get("last_name")
                full_name = f"{first_name} {last_name}" if last_name else first_name
                user_input = CreateUserInput(
                    telegram_id=telegram_id,
                    full_name=full_name,
                    username=user_obj.get("username"),
                    language_code=user_obj.get("language_code"),
                )
                await user_service.create(user_input, settings=settings)
                logger.info(f"Auto-registered user {telegram_id} via Mini App initData")
            except Exception as exc:
                logger.warning(f"Auto-register failed for user {telegram_id}: {exc}")

    token = create_access_token(
        {"telegram_id": telegram_id, "source": "miniapp"},
        get_secret(request),
    )
    response = JSONResponse({"ok": True, "telegram_id": telegram_id})
    response.set_cookie("access_token", token, httponly=True, samesite="none", secure=True, max_age=86400)
    return response


@router.post("/check")
async def auth_check_telegram_id(request: Request, body: LoginRequest):
    """Step 1 of web login: check if telegram_id has web credentials."""
    container: AsyncContainer = request.app.state.dishka_container
    async with container(scope=Scope.REQUEST) as req_container:
        uow: UnitOfWork = await req_container.get(UnitOfWork)
        user_service: UserService = await req_container.get(UserService)

        user = await user_service.get(telegram_id=body.telegram_id)
        if user is None:
            raise HTTPException(status_code=404, detail="Пользователь с таким Telegram ID не найден")

        cred = await uow.repository.web_credentials.get_by_telegram_id(body.telegram_id)
        return JSONResponse({
            "has_credentials": cred is not None,
            "name": user.name,
            "web_username": cred.web_username if cred else None,
        })


@router.post("/register")
async def auth_register(request: Request, body: RegisterRequest):
    """Register web credentials for a telegram user."""
    if len(body.password) < 6:
        raise HTTPException(status_code=400, detail="Пароль должен быть не менее 6 символов")
    if len(body.web_username) < 3:
        raise HTTPException(status_code=400, detail="Логин должен быть не менее 3 символов")

    container: AsyncContainer = request.app.state.dishka_container
    async with container(scope=Scope.REQUEST) as req_container:
        uow: UnitOfWork = await req_container.get(UnitOfWork)
        user_service: UserService = await req_container.get(UserService)

        user = await user_service.get(telegram_id=body.telegram_id)
        if user is None:
            raise HTTPException(status_code=404, detail="Пользователь с таким Telegram ID не найден")

        existing = await uow.repository.web_credentials.get_by_telegram_id(body.telegram_id)
        if existing:
            raise HTTPException(status_code=409, detail="Учётные данные уже существуют")

        username_taken = await uow.repository.web_credentials.get_by_username(body.web_username)
        if username_taken:
            raise HTTPException(status_code=409, detail="Этот логин уже занят")

        try:
            pw_hash = hash_password(body.password)
        except Exception as exc:
            logger.error(f"Password hashing failed: {exc}")
            raise HTTPException(status_code=500, detail="Ошибка при создании учётных данных")

        credential = WebCredential(
            telegram_id=body.telegram_id,
            web_username=body.web_username,
            password_hash=pw_hash,
        )
        try:
            await uow.repository.web_credentials.create(credential)
            await uow.commit()
        except Exception as exc:
            logger.error(f"Failed to save web credentials: {exc}")
            raise HTTPException(status_code=500, detail="Ошибка при сохранении учётных данных")

    token = create_access_token(
        {"telegram_id": body.telegram_id, "source": "web"},
        get_secret(request),
    )
    response = JSONResponse({"ok": True})
    response.set_cookie("access_token", token, httponly=True, samesite="lax", secure=True, max_age=86400)
    return response


@router.post("/login")
async def auth_login(request: Request, body: PasswordLoginRequest):
    """Login with username + password."""
    container: AsyncContainer = request.app.state.dishka_container
    async with container(scope=Scope.REQUEST) as req_container:
        uow: UnitOfWork = await req_container.get(UnitOfWork)

        cred = await uow.repository.web_credentials.get_by_username(body.web_username)
        if cred is None:
            raise HTTPException(status_code=401, detail="Неверный логин или пароль")

        if not verify_password(body.password, cred.password_hash):
            raise HTTPException(status_code=401, detail="Неверный логин или пароль")

    token = create_access_token(
        {"telegram_id": cred.telegram_id, "source": "web"},
        get_secret(request),
    )
    response = JSONResponse({"ok": True})
    response.set_cookie("access_token", token, httponly=True, samesite="lax", secure=True, max_age=86400)
    return response


@router.post("/logout")
async def auth_logout():
    response = JSONResponse({"ok": True})
    response.delete_cookie("access_token")
    return response


# ---------------------------------------------------------------------------
# Bot deeplink auth (no phone, opens the Telegram app directly)
# ---------------------------------------------------------------------------

_BOT_AUTH_TTL = 300  # 5 minutes


@router.post("/tg-bot/start")
async def tg_bot_auth_start(request: Request):
    """Step 1: generate a one-time token and return a bot deeplink.

    The client should open the returned ``bot_link`` in a new tab/window and
    then poll ``GET /tg-bot/poll/{token}`` until it gets ``status=ok``.
    """
    bot_username = ReferralService._bot_username or ""
    if not bot_username:
        raise HTTPException(status_code=503, detail="Бот ещё не готов, попробуйте позже")

    token = secrets.token_urlsafe(24)
    bot_link = f"https://t.me/{bot_username}?start=auth_{token}"

    container: AsyncContainer = request.app.state.dishka_container
    async with container(scope=Scope.REQUEST) as req_container:
        redis: RedisRepository = await req_container.get(RedisRepository)
        await redis.set(WebAuthKey(token=token), {"status": "pending"}, ex=_BOT_AUTH_TTL)

    logger.debug(f"Bot web-auth token issued: {token[:8]}…")
    return JSONResponse({"token": token, "bot_link": bot_link})


@router.get("/tg-bot/poll/{token}")
async def tg_bot_auth_poll(token: str, request: Request):
    """Step 2 (polling): check whether the user confirmed the login in the bot.

    Returns ``{"status": "pending"}`` while waiting, ``{"status": "ok", ...}``
    on success (sets JWT cookie), or 404 when the token has expired.
    """
    container: AsyncContainer = request.app.state.dishka_container

    async with container(scope=Scope.REQUEST) as req_container:
        redis: RedisRepository = await req_container.get(RedisRepository)
        data = await redis.get(WebAuthKey(token=token), dict)

    if data is None:
        raise HTTPException(status_code=404, detail="Токен истёк или недействителен")

    if data.get("status") != "ok":
        return JSONResponse({"status": "pending"})

    telegram_id = data["telegram_id"]

    # Consume the token so it can't be reused
    async with container(scope=Scope.REQUEST) as req_container:
        redis: RedisRepository = await req_container.get(RedisRepository)
        await redis.delete(WebAuthKey(token=token))

    logger.info(f"Bot web-auth success for telegram_id={telegram_id}")

    jwt_token = create_access_token(
        {"telegram_id": telegram_id, "source": "bot_deeplink"},
        get_secret(request),
    )
    response = JSONResponse({
        "status": "ok",
        "telegram_id": telegram_id,
        "name": data.get("name", ""),
    })
    response.set_cookie(
        "access_token", jwt_token,
        httponly=True, samesite="lax", secure=True, max_age=86400 * 30,
    )
    return response
