# LearningSteps API image

# Stage 1: install the Python packages into a virtual environment
FROM python:3.12-slim AS build
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY api/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

# Stage 2: the image that runs. Only the packages and the app code are copied in.
FROM python:3.12-slim
# Apply Debian package updates released after this base image was built
# (Trivy found a fixed HIGH vulnerability in libpcre2-8-0)
RUN apt-get update \
    && apt-get upgrade -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
RUN groupadd --system --gid 1001 api \
    && useradd --system --uid 1001 --gid api --no-create-home --shell /usr/sbin/nologin api
COPY --from=build /opt/venv /opt/venv
WORKDIR /app
COPY api/ .
USER 1001
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]