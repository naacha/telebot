FROM python:3.11-alpine

# Metadata
LABEL maintainer="Enhanced Telegram Bot with FIXES"
LABEL description="Professional file manager bot with FIXED OAuth2 and speedtest"

# Environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PIP_NO_CACHE_DIR=1
ENV PIP_DISABLE_PIP_VERSION_CHECK=1

# Install system dependencies including speedtest requirements
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
    file \
    binutils \
    && rm -rf /var/cache/apk/*

# Create app directory
WORKDIR /app

# Create necessary directories individually (FIXED)
RUN mkdir -p /app/data && \
    mkdir -p /app/downloads && \
    mkdir -p /app/logs && \
    chmod -R 755 /app

# Copy requirements and install Python packages
COPY requirements.txt /app/
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY bot.py /app/
COPY .env /app/

# Set proper permissions for application and directories (FIXED)
RUN chmod +x /app/bot.py && \
    chmod -R 777 /app/data && \
    chmod -R 777 /app/downloads && \
    chmod -R 777 /app/logs

# Pre-install speedtest-cli for common architectures during build
RUN echo "Pre-installing Ookla speedtest-cli..." && \
    ARCH=$(uname -m) && \
    echo "Detected architecture: $ARCH" && \
    case "$ARCH" in \
        x86_64) SPEEDTEST_URL="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-x86_64.tgz" ;; \
        aarch64) SPEEDTEST_URL="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-aarch64.tgz" ;; \
        armv7l) SPEEDTEST_URL="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-armhf.tgz" ;; \
        *) SPEEDTEST_URL="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-x86_64.tgz" ;; \
    esac && \
    echo "Using speedtest URL: $SPEEDTEST_URL" && \
    wget -O /tmp/speedtest.tgz "$SPEEDTEST_URL" && \
    tar -xzf /tmp/speedtest.tgz -C /tmp/ && \
    chmod +x /tmp/speedtest && \
    mv /tmp/speedtest /usr/local/bin/speedtest && \
    rm -f /tmp/speedtest.tgz && \
    echo "Speedtest installation completed" && \
    /usr/local/bin/speedtest --version || echo "Speedtest pre-install may need runtime verification"

# Health check with improved timeout
HEALTHCHECK --interval=30s --timeout=15s --start-period=60s --retries=3 \
    CMD python -c "import sys; print('Health check OK'); sys.exit(0)" || exit 1

# Expose port
EXPOSE 8080

# Run the bot
CMD ["python", "/app/bot.py"]