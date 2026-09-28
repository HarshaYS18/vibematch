FROM python:3.13-slim-bookworm AS build
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_NO_CACHE_DIR=1
RUN python -m venv /opt/venv
COPY apps/kafka-event-bridge/requirements.txt /tmp/requirements.txt
RUN /opt/venv/bin/pip install --no-cache-dir -r /tmp/requirements.txt

FROM python:3.13-slim-bookworm
ENV PATH=/opt/venv/bin:$PATH PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1
WORKDIR /app
RUN groupadd --system funkey && useradd --system --gid funkey --home /app funkey
COPY --from=build /opt/venv /opt/venv
COPY --chown=funkey:funkey apps/kafka-event-bridge/ /app/
USER funkey
EXPOSE 8092
HEALTHCHECK --interval=30s --timeout=3s CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8092/live', timeout=2)" || exit 1
CMD ["python", "main.py"]
