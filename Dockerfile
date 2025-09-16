# Use Python 3.11 Alpine for ARM compatibility
FROM python:3.11-alpine

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONPATH=/app
ENV PYTHONIOENCODING=utf-8

# Install system dependencies (ARM-optimized)
RUN apk add --no-cache \
    gcc \
    g++ \
    musl-dev \
    linux-headers \
    libffi-dev \
    openssl-dev \
    curl \
    wget \
    git \
    sqlite \
    sudo \
    bash \
    nano \
    htop \
    procps \
    shadow \
    util-linux \
    coreutils \
    findutils \
    ca-certificates \
    tzdata \
    && rm -rf /var/cache/apk/*

# Create app directory
WORKDIR /app

# Create required directories
RUN mkdir -p /app/{data,downloads,logs,config,backup} \
    && mkdir -p /var/log/bot \
    && mkdir -p /var/run/bot

# Copy requirements first for better caching
COPY requirements-fixed.txt /app/requirements.txt

# Upgrade pip first
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

# Install Python dependencies in stages to handle ARM issues
RUN pip install --no-cache-dir requests==2.31.0 \
    && pip install --no-cache-dir aiohttp==3.8.6 \
    && pip install --no-cache-dir python-telegram-bot==20.7

# Install Google OAuth2 dependencies
RUN pip install --no-cache-dir google-auth==2.23.4 \
    && pip install --no-cache-dir google-auth-oauthlib==1.0.0 \
    && pip install --no-cache-dir google-auth-httplib2==0.1.1 \
    && pip install --no-cache-dir google-api-python-client==2.103.0

# Install utilities
RUN pip install --no-cache-dir humanize==4.8.0 tqdm==4.66.1 psutil==5.9.6

# Copy application files
COPY bot.py /app/
COPY system-manager.sh /app/
COPY cleanup.sh /app/
COPY healthcheck.sh /app/

# Make scripts executable
RUN chmod +x /app/*.sh

# Set permissions
RUN chmod -R 777 /app \
    && chmod -R 755 /var/log/bot \
    && chmod -R 755 /var/run/bot

# Create user with sudo access
RUN adduser -D -s /bin/bash botuser \
    && echo "botuser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD python -c "import requests; print('OK')" || exit 1

# Expose port for OAuth2 callback
EXPOSE 8080

# Set working directory
WORKDIR /app

# Default user (overridden with --user root)
USER botuser

# Entry point
CMD ["python", "/app/bot.py"]