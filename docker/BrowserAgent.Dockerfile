FROM mcr.microsoft.com/playwright/python:v1.48.0-jammy

WORKDIR /app/browseragent
COPY external/BrowserAgent/ /app/browseragent/
COPY agents/browseragent/run_webmall_smoke.py /app/browseragent/run_webmall_smoke.py

RUN pip install --no-cache-dir playwright==1.48.0
RUN python -m playwright install chromium

ENV WEBMALL_BASE_URL=""
ENV TASKSET_PATH="/tasksets/task_sets.json"
ENV RESULTS_DIR="/results/browser"

CMD ["bash","-lc","echo 'BrowserAgent image ready (Playwright installed)'; tail -f /dev/null"]
