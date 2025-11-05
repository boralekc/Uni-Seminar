# runner/run_browseragent_webmall.py
import os, sys, json, re, subprocess, tempfile
from pathlib import Path

# ---- ENV ----
TASKSET_PATH = os.getenv("TASKSET_PATH", "/tasksets/task_sets.json")
RESULTS_DIR  = os.getenv("RESULTS_DIR", "/results")
EPISODES     = os.getenv("EPISODES", "1")

EXCLUDED_CATEGORIES = [
    c.strip() for c in os.getenv("EXCLUDED_CATEGORIES", "Add_To_Cart,Checkout,FindAndOrder").split(",") if c.strip()
]

URLS = {
    "{{URL_1}}": os.getenv("SHOP1_URL", ""),
    "{{URL_2}}": os.getenv("SHOP2_URL", ""),
    "{{URL_3}}": os.getenv("SHOP3_URL", ""),
    "{{URL_4}}": os.getenv("SHOP4_URL", ""),
    "{{URL_5}}": os.getenv("FRONTEND_URL", ""),
}

SMOKE = Path("/app/agentoccam/run_agentoccam.py")  # лежит внутри образа BrowserAgent
if not SMOKE.exists():
    print("ERROR: /app/agentoccam/run_agentoccam.py not found")
    sys.exit(1)

def warn(msg): print(f"WARNING: {msg}")
def info(msg): print(f"INFO: {msg}")

def replace_placeholders(obj):
    if isinstance(obj, dict):
        return {k: replace_placeholders(v) for k,v in obj.items()}
    if isinstance(obj, list):
        return [replace_placeholders(x) for x in obj]
    if isinstance(obj, str):
        for ph, val in URLS.items():
            if val:
                obj = obj.replace(ph, val)

        if "Solution page:" in obj:
            obj = re.sub(
              r"Solution page:.*?Do not forget to press the \"Submit Final Result\" button in all cases!",
              ("If a store page does not load, refresh up to three times. "
               "Return only the final result URLs (separated by ###). "
               "If not URLs, return the values. If nothing to return, answer 'Done'."),
              obj, flags=re.DOTALL)
        return obj
    return obj

def load_and_resolve_taskset(path:str):
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    resolved = []
    skipped = 0
    for suite in data:
        out_suite = dict(suite)
        tasks = []
        for t in suite.get("tasks", []):
            cat = t.get("category","")
            if cat in EXCLUDED_CATEGORIES:
                skipped += 1
                continue
            tasks.append(replace_placeholders(t))
        out_suite["tasks"] = tasks
        resolved.append(out_suite)
    info(f"Resolved tasks: kept {sum(len(s['tasks']) for s in resolved)}, skipped {skipped}: {EXCLUDED_CATEGORIES}")
    return resolved

def main():
    if not Path(TASKSET_PATH).exists():
        print(f"ERROR: TASKSET_PATH not found: {TASKSET_PATH}")
        sys.exit(1)

    resolved = load_and_resolve_taskset(TASKSET_PATH)


    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as tf:
        json.dump(resolved, tf, ensure_ascii=False, indent=2)
        resolved_path = tf.name

    Path(RESULTS_DIR).mkdir(parents=True, exist_ok=True)

    cmd = [
        "python", str(SMOKE),
        "--taskset", resolved_path,
        "--results", RESULTS_DIR,
        "--episodes", EPISODES
    ]
    print("Running:", " ".join(cmd))
    rc = subprocess.call(cmd)
    sys.exit(rc)

if __name__ == "__main__":
    main()
