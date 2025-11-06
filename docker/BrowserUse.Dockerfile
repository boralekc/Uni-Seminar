FROM mcr.microsoft.com/playwright/python:v1.48.0-noble
# noble = Ubuntu 24.04, Python 3.12

WORKDIR /app

RUN python -m pip install --upgrade pip

COPY runner/run_browseruse_webmall_study.py /app/runner/run_browseruse_webmall_study.py

RUN pip install --no-cache-dir \
    browser-use \
    python-dotenv>=1.0 \
    gymnasium==0.29.* \
    numpy>=1.24 \
    pandas>=2.0 \
    tqdm>=4.66 \
    "pydantic<3" \
    requests>=2.31 \
    playwright==1.48.* \
    "pyparsing>=3.1,<4" \
    "Pillow>=10,<11" \
    packaging>=23 \
    "beautifulsoup4>=4.12,<5" \
    "lxml>=4.9"

RUN python -m playwright install chromium --with-deps

ENV PYTHONPATH="/ext/webmall:/ext/core:${PYTHONPATH}"
ENV WEBMALL_BASE_URL=""
ENV TASKSET_PATH="/app/tasksets/task_sets.json"
ENV RESULTS_DIR="/app/results"

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s \
  CMD python -c "print('ok')" || exit 1

CMD ["bash","-lc","echo 'browser-use image ready'; tail -f /dev/null"]
