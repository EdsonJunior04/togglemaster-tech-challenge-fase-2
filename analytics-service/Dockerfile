FROM python:3.13-alpine3.24

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV OTEL_TRACES_EXPORTER=none
ENV OTEL_METRICS_EXPORTER=none

COPY requirements.txt ./

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN addgroup -S appgroup && adduser -S appuser -G appgroup \
    && chown -R appuser:appgroup /app

USER appuser

EXPOSE 8005

CMD ["opentelemetry-instrument", "gunicorn", "--bind", "0.0.0.0:8005", "app:app"]