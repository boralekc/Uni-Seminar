FROM mcr.microsoft.com/playwright/python:v1.48.0-jammy

WORKDIR /app/browseruse

COPY runner/run_browseruse_webmall_study.py /app/browseruse/run_browseruse_webmall_study.py

RUN pip install --no-cache-dir \
    "gymnasium==0.29.*" \
    "numpy>=1.24" \
    "pandas>=2.0" \
    "tqdm>=4.66" \
    "pydantic<2" \
    "requests>=2.31" \
    "playwright==1.48.*" \
    "pyparsing>=3.1,<4" \
    "Pillow>=10,<11" \
    "packaging>=23" \
    "beautifulsoup4>=4.12,<5" \
    "lxml>=4.9" \
    "python-dotenv>=1.0"

RUN python -m playwright install chromium --with-deps

ENV PYTHONPATH="/ext/webmall:/ext/core:${PYTHONPATH}"
ENV WEBMALL_BASE_URL=""
ENV TASKSET_PATH="/tasksets/task_sets.json"
ENV RESULTS_DIR="/results/browser"

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s CMD pgrep chromium || exit 1

CMD ["bash","-lc","echo 'BrowserAgent image ready (Playwright installed)'; tail -f /dev/null"]
