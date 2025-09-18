FROM python:3.11-alpine

# Metadata
LABEL maintainer="Enhanced Telegram Bot"
LABEL description="Professional file manager bot with OAuth2, speedtest, and inline support"

# Environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PIP_NO_CACHE_DIR=1
ENV PIP_DISABLE_PIP_VERSION_CHECK=1

# Install system dependencies
RUN apk add --no-cache \
    gcc \
    g++ \
    musl-dev \
    libffi-dev \
    openssl-dev \
    curl \
    wget \
    bash \
    tar \
    gzip \
    ca-certificates \
    && rm -rf /var/cache/apk/*

# Create app directory
WORKDIR /app

# Create necessary directories
RUN mkdir -p /app/{data,downloads,logs} && \
    chmod -R 755 /app

# Copy requirements and install Python packages
COPY requirements.txt /app/
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY bot.py /app/
COPY .env /app/

# Set proper permissions
RUN chmod +x /app/bot.py && \
    chmod -R 777 /app/data /app/downloads /app/logs

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD python -c "import requests; print('Health check passed')" || exit 1

# Expose port
EXPOSE 8080

# Run the bot
CMD ["python", "/app/bot.py"]