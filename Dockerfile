# Use Python 3.11 Alpine for minimal size
FROM python:3.11-alpine

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONPATH=/app

# Install system dependencies
RUN apk add --no-cache     gcc     g++     musl-dev     linux-headers     libffi-dev     openssl-dev     curl     wget     git     sqlite     sudo     bash     nano     htop     procps     shadow     util-linux     coreutils     ca-certificates     tzdata

# Create app directory
WORKDIR /app

# Create required directories
RUN mkdir -p /app/{data,downloads,logs,config,backup}     && mkdir -p /var/log/bot     && mkdir -p /var/run/bot

# Copy requirements first for better caching
COPY requirements.txt /app/

# Install Python dependencies with OAuth2 libraries
RUN pip install --no-cache-dir --upgrade pip     && pip install --no-cache-dir -r requirements.txt

# Copy application files (NO credentials.json!)
COPY bot.py /app/
COPY system-manager.sh /app/
COPY cleanup.sh /app/
COPY healthcheck.sh /app/

# Make scripts executable
RUN chmod +x /app/*.sh

# Set permissions for OAuth2 token storage
RUN chmod -R 777 /app     && chmod -R 755 /var/log/bot     && chmod -R 755 /var/run/bot

# Create user with sudo access
RUN adduser -D -s /bin/bash botuser     && echo "botuser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Health check with OAuth2 status
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3     CMD /app/healthcheck.sh || exit 1

# Expose port for OAuth2 callback
EXPOSE 8080

# Set working directory
WORKDIR /app

# Default user (can be overridden with --user root)
USER botuser

# Entry point
CMD ["python", "/app/bot.py"]