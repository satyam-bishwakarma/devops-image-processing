FROM node:22-bookworm-slim AS frontend
WORKDIR /src
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ ./
RUN npm run build

FROM python:3.12-alpine3.24
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
COPY backend/requirements.txt /app/requirements.txt
RUN apk upgrade --no-cache \
    && pip install --no-cache-dir --only-binary=:all: -r requirements.txt
COPY backend/app.py /app/backend/app.py
COPY --from=frontend /src/dist /app/frontend/dist
ARG APP_VERSION=local
ENV APP_VERSION=${APP_VERSION}
USER 10001:10001
EXPOSE 8000
CMD ["uvicorn", "backend.app:app", "--host", "0.0.0.0", "--port", "8000", "--limit-concurrency", "16"]
