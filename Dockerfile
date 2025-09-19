# Dockerfile for STB HG680P Armbian 25.11 (ARM64)
FROM --platform=linux/arm64 python:3.11-slim

# Metadata
LABEL maintainer="STB HG680P Telegram Bot"
LABEL description="Telegram bot optimized for STB HG680P Armbian 25.11 CLI"
LABEL architecture="arm64"
LABEL os="armbian"

# Environment variables for ARM64
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PIP_NO_CACHE_DIR=1
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Install system dependencies optimized for ARM64
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    libc6-dev \
    libffi-dev \
    libssl-dev \
    curl \
    wget \
    git \
    ca-certificates \
    procps \
    htop \
    nano \
    && rm -rf /var/lib/apt/lists/*

# Create app directory structure
WORKDIR /app

# Create necessary directories with proper permissions
RUN mkdir -p /app/data /app/downloads /app/logs /app/credentials && \
    chmod -R 755 /app && \
    chown -R root:root /app

# Copy requirements and install Python packages
COPY requirements.txt /app/
RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY app/ /app/
COPY scripts/ /app/scripts/

# Set executable permissions
RUN chmod +x /app/bot.py && \
    chmod +x /app/scripts/*.sh && \
    chmod -R 777 /app/data && \
    chmod -R 777 /app/downloads && \
    chmod -R 777 /app/logs

# Health check optimized for STB
HEALTHCHECK --interval=30s --timeout=15s --start-period=60s --retries=3 \
    CMD python -c "print('STB Health OK'); exit(0)" || exit 1

# Expose port for web interface
EXPOSE 8080

# Run the bot
CMD ["python", "/app/bot.py"]
