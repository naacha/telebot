#!/bin/bash

# Alternative Ubuntu-based build for problematic ARM systems
# Sometimes Alpine doesn't work well on certain ARM architectures

echo "🔧 Building with Ubuntu base (Alternative method)"
echo "================================================="

cd "$(dirname "$0")"

if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

IMAGE_NAME=${IMAGE_NAME:-"bot-tele-3:latest"}

# Create Ubuntu-based Dockerfile
cat > Dockerfile.ubuntu << 'EOF'
FROM python:3.11-slim

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV DEBIAN_FRONTEND=noninteractive

# Update and install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    curl \
    wget \
    git \
    sqlite3 \
    sudo \
    nano \
    htop \
    procps \
    ca-certificates \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Create directories
RUN mkdir -p /app/{data,downloads,logs,config,backup} /var/log/bot /var/run/bot

# Copy requirements
COPY requirements.txt /app/

# Install Python packages
RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r requirements.txt

# Copy app files
COPY bot.py /app/
COPY *.sh /app/

# Set permissions
RUN chmod +x /app/*.sh && \
    chmod -R 777 /app

# Create user
RUN useradd -m -s /bin/bash botuser && \
    echo "botuser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Health check
HEALTHCHECK --interval=30s --timeout=10s \
    CMD python -c "import sys; sys.exit(0)"

EXPOSE 8080
USER botuser
CMD ["python", "/app/bot.py"]
EOF

echo "🔨 Building with Ubuntu base..."
if docker build -f Dockerfile.ubuntu -t ${IMAGE_NAME} .; then
    echo "✅ Ubuntu build successful!"
    rm -f Dockerfile.ubuntu
else
    echo "❌ Ubuntu build also failed"
    exit 1
fi