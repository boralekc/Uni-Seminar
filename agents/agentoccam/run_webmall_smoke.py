import argparse, os, time, json
from pathlib import Path
from playwright.sync_api import sync_playwright

def run_once(base_url: str, out_dir: Path):
    out_dir.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        ctx = browser.new_context(viewport={"width":1280,"height":800})
        page = ctx.new_page()
        page.goto(base_url, wait_until="domcontentloaded", timeout=30000)
        time.sleep(1.0)
        page.screenshot(path=str(out_dir / "home.png"))

        first_link = page.locator("a").first
        if first_link.count() > 0:
            href = first_link.get_attribute("href") or ""
            try:
                first_link.click(timeout=5000)
                page.wait_for_load_state("domcontentloaded", timeout=10000)
                page.screenshot(path=str(out_dir / "after_click.png"))
            except Exception:
                pass
        ctx.close()
        browser.close()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base-url", required=True)
    ap.add_argument("--taskset", default="")
    ap.add_argument("--episodes", type=int, default=1)
    ap.add_argument("--out", default="/results/occam")
    args = ap.parse_args()

    out_root = Path(args.out)
    meta = {"base_url": args.base_url, "taskset": args.taskset, "episodes": args.episodes, "runs":[]}
    for i in range(args.episodes):
        run_dir = out_root / f"run_{i+1:02d}"
        run_once(args.base_url, run_dir)
        meta["runs"].append({"run": i+1, "dir": str(run_dir)})
    (out_root / "smoke_meta.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")

if __name__ == "__main__":
    main()
