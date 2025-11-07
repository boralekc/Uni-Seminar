FROM mcr.microsoft.com/playwright/python:v1.48.0-noble
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
WORKDIR /app

RUN pip install --no-cache-dir \
    "playwright==1.48.*" \
    "browser-use>=0.7.0,<0.8" \
    "python-dotenv>=1.0" \
    "tqdm>=4.66" \
    "requests>=2.31" \
    "beautifulsoup4>=4.12,<5" \
    "lxml>=4.9"

RUN python -m playwright install chromium --with-deps

RUN mkdir -p /app/runner
COPY /runner/run_browseruse_webmall_study.py /app/runner/run_browseruse_webmall_study.py
WORKDIR /app/runner
