FROM python:3.13-slim-bookworm AS build
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_NO_CACHE_DIR=1
WORKDIR /build
RUN python -m venv /opt/venv
COPY backend/requirements.txt ./backend-requirements.txt
COPY apps/graphql-bff/requirements.txt ./graphql-bff-requirements.txt
RUN /opt/venv/bin/pip install --no-cache-dir -r backend-requirements.txt -r graphql-bff-requirements.txt

FROM python:3.13-slim-bookworm
ENV PATH=/opt/venv/bin:$PATH PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=/app/apps/graphql-bff
WORKDIR /app/apps/graphql-bff
RUN groupadd --system funkey && useradd --system --gid funkey --home /app funkey
COPY --from=build /opt/venv /opt/venv
COPY --chown=funkey:funkey apps/graphql-bff/ /app/apps/graphql-bff/
USER funkey
EXPOSE 8091
HEALTHCHECK --interval=30s --timeout=3s CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8091/live', timeout=2)" || exit 1
CMD ["uvicorn","main:app","--host","0.0.0.0","--port","8091","--proxy-headers","--timeout-graceful-shutdown","30","--no-access-log"]
