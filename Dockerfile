FROM node:20-alpine AS frontend-builder

WORKDIR /opt/remnasale/frontend

COPY ./frontend/package.json ./frontend/package-lock.json ./
COPY ./frontend/packages ./packages

RUN --mount=type=cache,target=/root/.npm \
    npm install && npm run build:miniapp && npm run build:website

FROM ghcr.io/astral-sh/uv:python3.12-alpine AS builder

WORKDIR /opt/remnasale

COPY pyproject.toml uv.lock ./

RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --no-dev --compile-bytecode \
    && rm -rf .venv/lib/python3.12/site-packages/pip* \
    && rm -rf .venv/lib/python3.12/site-packages/setuptools* \
    && rm -rf .venv/lib/python3.12/site-packages/wheel*

FROM python:3.12-alpine AS final

WORKDIR /opt/remnasale

# 1. System deps (cached, rarely change)
RUN apk add --no-cache postgresql-client docker-cli

# 2. Python venv (cached until pyproject.toml changes)
COPY --from=builder /opt/remnasale/.venv /opt/remnasale/.venv

ENV PATH="/opt/remnasale/.venv/bin:$PATH"
ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/opt/remnasale

# 3. Scripts (change rarely)
COPY ./scripts ./scripts
RUN chmod +x ./scripts/docker-entrypoint.sh \
    && chmod +x ./scripts/docker-entrypoint-worker.sh \
    && chmod +x ./scripts/docker-entrypoint-scheduler.sh

# 4. Assets and translations (change occasionally)
COPY ./assets /opt/remnasale/assets.default
COPY ./assets/translations /opt/remnasale/assets/translations

# Pre-compile FTL translations to .pyc bytecode at build time
RUN python3 ./scripts/precompile_translations.py \
    /opt/remnasale/assets/translations \
    /opt/remnasale/assets/ftl_precompiled

# 5. Source code (changes on most updates)
COPY ./src ./src

# 6. Frontend builds
COPY --from=frontend-builder /opt/remnasale/frontend/packages/miniapp/dist ./miniapp-dist
COPY --from=frontend-builder /opt/remnasale/frontend/packages/website/dist ./website-dist

# 7. Version
COPY ./version ./version

# 8. Build metadata (changes every build — LAST to maximize cache hits)
ARG BUILD_TIME
ARG BUILD_BRANCH
ARG BUILD_COMMIT
ARG BUILD_TAG
ENV BUILD_TIME=${BUILD_TIME} \
    BUILD_BRANCH=${BUILD_BRANCH} \
    BUILD_COMMIT=${BUILD_COMMIT} \
    BUILD_TAG=${BUILD_TAG}

CMD ["./scripts/docker-entrypoint.sh"]
