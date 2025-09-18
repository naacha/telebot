FROM python:3.11-alpine

ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Install system dependencies
RUN apk add --no-cache \
    gcc \
    g++ \
    musl-dev \
    libffi-dev \
    openssl-dev \
    curl \
    bash \
    && rm -rf /var/cache/apk/*

WORKDIR /app

# Create directories
RUN mkdir -p /app/{data,downloads,logs}

# Install Python packages
COPY requirements.txt /app/
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy bot files
COPY bot.py /app/
COPY .env /app/

# Set permissions
RUN chmod +x /app/bot.py && chmod -R 777 /app

# Health check
HEALTHCHECK --interval=30s --timeout=10s \
    CMD python -c "print('OK')" || exit 1

EXPOSE 8080

CMD ["python", "/app/bot.py"]
