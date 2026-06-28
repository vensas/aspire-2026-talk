FROM python:3.14-slim-bookworm

RUN groupadd --system --gid 999 appuser && useradd --system --gid 999 --uid 999 --create-home appuser

WORKDIR /app

COPY requirements.txt /app/requirements.txt

RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential \
  && pip install --no-cache-dir -r requirements.txt \
  && apt-get purge -y --auto-remove build-essential \
  && rm -rf /var/lib/apt/lists/*

COPY --chown=appuser:appuser . /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

USER appuser

ENTRYPOINT ["python","sensor.py"]
