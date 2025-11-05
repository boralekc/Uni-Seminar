
FROM mcr.microsoft.com/playwright/python:v1.48.0-jammy

WORKDIR /app/browseragent

COPY external/BrowserAgent/ /app/browseragent/
COPY runner/run_browseragent.py /app/browseragent/run_browseragent.py

RUN pip install --no-cache-dir playwright==1.48.0

RUN python -m playwright install chromium --with-deps

ENV PYTHONPATH="/ext/webmall:/ext/core:${PYTHONPATH}"
ENV WEBMALL_BASE_URL=""
ENV TASKSET_PATH="/tasksets/task_sets.json"
ENV RESULTS_DIR="/results/browser"

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s CMD pgrep chromium || exit 1

CMD ["bash","-lc","echo 'BrowserAgent image ready (Playwright installed)'; tail -f /dev/null"]
