# syntax=docker/dockerfile:1.7
# =============================================================================
# Plane All-in-One Dockerfile for Free Tier Deployment
# This builds API (Django), Worker (Celery), and Web (React) in one container
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Build Frontend (Web App)
# -----------------------------------------------------------------------------
FROM node:22-alpine AS frontend-builder

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable

WORKDIR /app

# Install dependencies
RUN apk add --no-cache libc6-compat git

# Copy package files
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml turbo.json ./
COPY packages ./packages
COPY apps/web ./apps/web

# Install dependencies
RUN corepack enable pnpm
RUN pnpm install --frozen-lockfile

# Build arguments for frontend
ARG VITE_API_BASE_URL=""
ARG VITE_ADMIN_BASE_URL=""
ARG VITE_ADMIN_BASE_PATH="/god-mode"
ARG VITE_LIVE_BASE_URL=""
ARG VITE_LIVE_BASE_PATH="/live"
ARG VITE_SPACE_BASE_URL=""
ARG VITE_SPACE_BASE_PATH="/spaces"
ARG VITE_WEB_BASE_URL=""

ENV VITE_API_BASE_URL=$VITE_API_BASE_URL
ENV VITE_ADMIN_BASE_URL=$VITE_ADMIN_BASE_URL
ENV VITE_ADMIN_BASE_PATH=$VITE_ADMIN_BASE_PATH
ENV VITE_LIVE_BASE_URL=$VITE_LIVE_BASE_URL
ENV VITE_LIVE_BASE_PATH=$VITE_LIVE_BASE_PATH
ENV VITE_SPACE_BASE_URL=$VITE_SPACE_BASE_URL
ENV VITE_SPACE_BASE_PATH=$VITE_SPACE_BASE_PATH
ENV VITE_WEB_BASE_URL=$VITE_WEB_BASE_URL
ENV NEXT_TELEMETRY_DISABLED=1
ENV TURBO_TELEMETRY_DISABLED=1

# Build the web app
RUN pnpm turbo run build --filter=web

# -----------------------------------------------------------------------------
# Stage 2: Build Backend (Django API)
# -----------------------------------------------------------------------------
FROM python:3.12.10-alpine AS backend

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /code

# Install system dependencies
RUN apk update && apk upgrade && \
    apk add --no-cache \
    libpq \
    libxslt \
    xmlsec \
    ca-certificates \
    openssl \
    libffi-dev \
    bash \
    nginx \
    supervisor \
    curl

# Install Python build dependencies and packages
COPY apps/api/requirements.txt ./
COPY apps/api/requirements ./requirements

RUN apk add --no-cache --virtual .build-deps \
    g++ \
    gcc \
    cargo \
    git \
    make \
    postgresql-dev \
    libc-dev \
    linux-headers && \
    pip install -r requirements.txt --compile --no-cache-dir && \
    apk del .build-deps && \
    rm -rf /var/cache/apk/*

# Copy Django application
COPY apps/api/manage.py manage.py
COPY apps/api/plane plane/
COPY apps/api/templates templates/
COPY apps/api/package.json package.json
COPY apps/api/bin ./bin/

# Copy built frontend from previous stage
COPY --from=frontend-builder /app/apps/web/build/client /code/static/web

# Create necessary directories and set permissions
RUN mkdir -p /code/plane/logs /code/static /var/log/supervisor /var/run /etc/supervisor/conf.d && \
    chmod +x ./bin/* && \
    chmod -R 777 /code

# Configure nginx
RUN rm -f /etc/nginx/http.d/default.conf
COPY <<EOF /etc/nginx/http.d/plane.conf
server {
    listen 3000;
    server_name _;
    client_max_body_size 20M;

    # Serve frontend
    location / {
        root /code/static/web;
        try_files \$uri \$uri/ /index.html;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    # Proxy API requests
    location /api/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Proxy admin requests
    location /god-mode/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Configure supervisor to run multiple processes
RUN printf '[supervisord]\n\
nodaemon=true\n\
user=root\n\
logfile=/dev/stdout\n\
logfile_maxbytes=0\n\
pidfile=/var/run/supervisord.pid\n\
\n\
[program:nginx]\n\
command=/usr/sbin/nginx -g "daemon off;"\n\
autostart=true\n\
autorestart=true\n\
stdout_logfile=/dev/stdout\n\
stdout_logfile_maxbytes=0\n\
stderr_logfile=/dev/stderr\n\
stderr_logfile_maxbytes=0\n\
\n\
[program:django]\n\
command=/code/bin/docker-entrypoint-api.sh\n\
directory=/code\n\
autostart=true\n\
autorestart=true\n\
stdout_logfile=/dev/stdout\n\
stdout_logfile_maxbytes=0\n\
stderr_logfile=/dev/stderr\n\
stderr_logfile_maxbytes=0\n\
\n\
[program:celery-worker]\n\
command=celery -A plane worker -l info\n\
directory=/code\n\
autostart=true\n\
autorestart=true\n\
stdout_logfile=/dev/stdout\n\
stdout_logfile_maxbytes=0\n\
stderr_logfile=/dev/stderr\n\
stderr_logfile_maxbytes=0\n\
\n\
[program:celery-beat]\n\
command=celery -A plane beat -l info\n\
directory=/code\n\
autostart=true\n\
autorestart=true\n\
stdout_logfile=/dev/stdout\n\
stdout_logfile_maxbytes=0\n\
stderr_logfile=/dev/stderr\n\
stderr_logfile_maxbytes=0\n' > /etc/supervisor/conf.d/plane.conf

# Health check - longer grace period for migrations
HEALTHCHECK --interval=30s --timeout=10s --start-period=180s --retries=5 \
    CMD curl -f http://localhost:3000/ || exit 1

EXPOSE 3000

# Create startup script
RUN echo '#!/bin/bash' > /code/start.sh && \
    echo 'set -e' >> /code/start.sh && \
    echo '' >> /code/start.sh && \
    echo 'echo "Starting Plane deployment..."' >> /code/start.sh && \
    echo '' >> /code/start.sh && \
    echo '# Run migrations (this may take a while on first deploy)' >> /code/start.sh && \
    echo 'echo "Running database migrations..."' >> /code/start.sh && \
    echo 'python manage.py migrate --noinput' >> /code/start.sh && \
    echo '' >> /code/start.sh && \
    echo '# Start supervisor' >> /code/start.sh && \
    echo 'echo "Starting services..."' >> /code/start.sh && \
    echo 'exec /usr/bin/supervisord -c /etc/supervisor/conf.d/plane.conf' >> /code/start.sh && \
    chmod +x /code/start.sh

CMD ["/code/start.sh"]
