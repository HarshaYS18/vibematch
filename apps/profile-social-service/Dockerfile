FROM python:3.13-slim-bookworm AS build
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_NO_CACHE_DIR=1
WORKDIR /build
RUN python -m venv /opt/venv
COPY backend/requirements.txt ./requirements.txt
RUN /opt/venv/bin/pip install --no-cache-dir -r requirements.txt
FROM python:3.13-slim-bookworm
ENV PATH=/opt/venv/bin:$PATH PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=/app/backend:/app/apps/profile-social-service
WORKDIR /app
RUN groupadd --system funkey && useradd --system --gid funkey --home /app funkey
COPY --from=build /opt/venv /opt/venv
COPY --chown=funkey:funkey backend/ /app/backend/
COPY --chown=funkey:funkey apps/profile-social-service/ /app/apps/profile-social-service/
USER funkey
EXPOSE 8087
CMD ["uvicorn","main:app","--app-dir","/app/apps/profile-social-service","--host","0.0.0.0","--port","8087","--proxy-headers","--timeout-graceful-shutdown","45","--no-access-log"]
