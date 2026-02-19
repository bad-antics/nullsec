FROM python:3.12-slim

LABEL maintainer="bad-antics" \
      description="Prompt Armor API — 8-layer AI prompt injection detection" \
      version="2.0.0"

WORKDIR /app

# Install package with API dependencies
COPY pyproject.toml README.md LICENSE ./
COPY prompt_armor/ ./prompt_armor/

RUN pip install --no-cache-dir ".[api]"

# Non-root user
RUN useradd -m armor && chown -R armor:armor /app
USER armor

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/v1/health')" || exit 1

CMD ["uvicorn", "prompt_armor.api:app", "--host", "0.0.0.0", "--port", "8080"]
