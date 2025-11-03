import json
import subprocess
from pathlib import Path
import argparse
import os
from rich import print

ALLOWED_AGENTS = {"occam": "agentoccam", "browser": "browseragent"}

def _container_out(container: str) -> str:
    return "/results/occam" if container == "agentoccam" else "/results/browser"

def _exec(container: str, base_url: str, taskset: str, episodes: int, agent_out: str):
    script = "/app/agentoccam/run_webmall_smoke.py" if container == "agentoccam" else "/app/browseragent/run_webmall_smoke.py"
    return [
        "docker","compose","exec","-T",container,"bash","-lc",
        f"python {script} --base-url '{base_url}' --taskset '{taskset}' --episodes {episodes} --out '{agent_out}'"
    ]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--agent", required=True, choices=list(ALLOWED_AGENTS.keys()))
    ap.add_argument("--base-url", default=os.getenv("WEBMALL_BASE_URL", "http://localhost:8080"))
    ap.add_argument("--taskset",  default=os.getenv("TASKSET_PATH", "./tasksets/task_sets.minimal.json"))
    ap.add_argument("--episodes", type=int, default=1)
    args = ap.parse_args()

    container = ALLOWED_AGENTS[args.agent]

    runner_results = Path(os.getenv("RESULTS_DIR", "/app/results"))
    runner_out = runner_results / args.agent
    runner_out.mkdir(parents=True, exist_ok=True)

    agent_out = _container_out(container)

    print(f"[bold cyan]Start {args.agent}[/] url={args.base_url} taskset={args.taskset} episodes={args.episodes}")
    cmd = _exec(container, args.base_url, args.taskset, args.episodes, agent_out)
    subprocess.check_call(cmd)

    (runner_out / f"{args.agent}_last_run.json").write_text(
        json.dumps({
            "agent": args.agent,
            "base_url": args.base_url,
            "taskset": args.taskset,
            "episodes": args.episodes,
            "agent_out": agent_out
        }, indent=2),
        encoding="utf-8"
    )
    print(f"[green]Done → {runner_out}[/]")

if __name__ == "__main__":
    main()
