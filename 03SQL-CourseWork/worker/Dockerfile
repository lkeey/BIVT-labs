FROM python:3.11-slim-bookworm

ARG DEBIAN_FRONTEND=noninteractive
ARG MSODBC_VERSION=18.7.1.1-1

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HF_HOME=/var/cache/coursework-hf

# The Microsoft Debian 12 repository publishes ODBC Driver 18 for both amd64
# and arm64. The package is signed by the key installed by its repository deb.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl libgomp1 libgssapi-krb5-2 passwd \
        tesseract-ocr tesseract-ocr-rus unixodbc-dev \
    && curl -fsSLo /tmp/packages-microsoft-prod.deb \
        https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb \
    && dpkg -i /tmp/packages-microsoft-prod.deb \
    && rm /tmp/packages-microsoft-prod.deb \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y --no-install-recommends \
        "msodbcsql18=${MSODBC_VERSION}" \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt requirements-embed.txt ./

# CPU-only PyTorch on amd64 avoids downloading unused CUDA libraries. On
# arm64, PyPI provides the CPU build used by sentence-transformers.
RUN if [ "$(dpkg --print-architecture)" = "amd64" ]; then \
        python -m pip install --no-cache-dir --disable-pip-version-check \
            torch --index-url https://download.pytorch.org/whl/cpu; \
    fi \
    && python -m pip install --no-cache-dir --disable-pip-version-check \
        -r requirements.txt

COPY index_worker.py embed_service.py pipeline.py ./

RUN groupadd --system --gid 10001 coursework \
    && useradd --system --uid 10001 --gid coursework \
        --home-dir /home/coursework --create-home coursework \
    && install -d -o coursework -g coursework "${HF_HOME}"

USER coursework
EXPOSE 8765

# The same image runs the private query-embedding service when its command is
# overridden with: python embed_service.py --host 0.0.0.0
CMD ["python", "index_worker.py", "--loop", "--poll-seconds", "10"]
