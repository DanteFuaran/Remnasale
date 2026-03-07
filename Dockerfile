FROM node:20-alpine AS frontend-builder

WORKDIR /opt/remnasale/frontend

COPY ./frontend/package.json ./frontend/package-lock.json ./
COPY ./frontend/packages ./packages

RUN npm install && npm run build:miniapp && npm run build:website

FROM ghcr.io/astral-sh/uv:python3.12-alpine AS builder

WORKDIR /opt/remnasale

COPY pyproject.toml uv.lock ./

RUN uv sync --no-dev --no-cache --compile-bytecode \
    && rm -rf .venv/lib/python3.12/site-packages/pip* \
    && rm -rf .venv/lib/python3.12/site-packages/setuptools* \
    && rm -rf .venv/lib/python3.12/site-packages/wheel*

FROM python:3.12-alpine AS final

WORKDIR /opt/remnasale

ARG BUILD_TIME
ARG BUILD_BRANCH
ARG BUILD_COMMIT
ARG BUILD_TAG

ENV BUILD_TIME=${BUILD_TIME}
ENV BUILD_BRANCH=${BUILD_BRANCH}
ENV BUILD_COMMIT=${BUILD_COMMIT}
ENV BUILD_TAG=${BUILD_TAG}

# Установляем postgresql-client и docker-cli
RUN apk add --no-cache postgresql-client docker-cli

COPY --from=builder /opt/remnasale/.venv /opt/remnasale/.venv

ENV PATH="/opt/remnasale/.venv/bin:$PATH"
ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/opt/remnasale

COPY ./src ./src
COPY --from=frontend-builder /opt/remnasale/frontend/packages/miniapp/dist ./miniapp-dist
COPY --from=frontend-builder /opt/remnasale/frontend/packages/website/dist ./website-dist
COPY ./version ./version
COPY ./assets /opt/remnasale/assets.default
# translations baked directly into image for fast startup (no volume I/O overhead)
COPY ./assets/translations /opt/remnasale/assets/translations
COPY ./scripts/docker-entrypoint.sh ./scripts/docker-entrypoint.sh
COPY ./scripts/docker-entrypoint-worker.sh ./scripts/docker-entrypoint-worker.sh
COPY ./scripts/docker-entrypoint-scheduler.sh ./scripts/docker-entrypoint-scheduler.sh
COPY ./scripts/precompile_translations.py ./scripts/precompile_translations.py

# Pre-compile FTL translations to .pyc bytecode at build time
# This converts ~44s CPU-bound compile_messages() at startup into ~50ms .pyc import.
# Output: /opt/remnasale/assets/ftl_precompiled/ftl_{locale}.py + __pycache__/*.pyc
RUN python3 ./scripts/precompile_translations.py \
    /opt/remnasale/assets/translations \
    /opt/remnasale/assets/ftl_precompiled

RUN chmod +x ./scripts/docker-entrypoint.sh \
    && chmod +x ./scripts/docker-entrypoint-worker.sh \
    && chmod +x ./scripts/docker-entrypoint-scheduler.sh

CMD ["./scripts/docker-entrypoint.sh"]
