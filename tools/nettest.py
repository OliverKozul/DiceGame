"""End-to-end network test: one direct-IP host and several clients, all headless, all played
by the bot brain. Checks that every instance that stays to the end sees the identical final
result and that no instance logged an error or had a request refused.

    python tools/nettest.py [--clients 3] [--bots 1] [--leave-at 4] [--turns 15] [--seed 11]
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

DEFAULT_GODOT = os.environ.get(
    "GODOT", r"C:\Users\Oli\Downloads\win64-g46-s163-gs4171-editor\GodotSteam4.6.exe"
)
PROBLEM_MARKERS = ("ERROR", "Request refused", "Autoplay request refused")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--godot", default=DEFAULT_GODOT)
    ap.add_argument("--clients", type=int, default=3)
    ap.add_argument("--bots", type=int, default=1)
    ap.add_argument("--leave-at", type=int, default=4, help="turn at which the last client quits (0: never)")
    ap.add_argument("--turns", type=int, default=15)
    ap.add_argument("--seed", type=int, default=11)
    ap.add_argument("--delay", type=float, default=0.0, help="bot delay in seconds")
    ap.add_argument("--timeout", type=float, default=300)
    args = ap.parse_args()

    project = Path(__file__).resolve().parent.parent
    base = [args.godot, "--headless", "--path", str(project), "--"]
    common = ["--autoplay", f"--bot-delay={args.delay}", "--quit-on-end"]
    log_dir = Path(tempfile.mkdtemp(prefix="dicegame-nettest-"))
    procs: list[tuple[str, subprocess.Popen, Path]] = []

    # Each instance logs to its own file; waiting on pipes one by one could stall the others.
    def launch(name: str, extra: list[str]) -> None:
        log = log_dir / f"{name}.log"
        cmd = base[:-1] + ["--log-file", str(log), "--"] + common + [f"--name={name}"] + extra
        procs.append((name, subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL), log))

    launch("Host", ["--autohost=enet", f"--expect={args.clients + 1}", f"--bots={args.bots}",
                    f"--seed={args.seed}", f"--turns={args.turns}"])
    time.sleep(1.5)
    for i in range(args.clients):
        extra = ["--autojoin=127.0.0.1"]
        if args.leave_at and i == args.clients - 1:
            extra.append(f"--leave-at-turn={args.leave_at}")
        launch(f"Client{i + 1}", extra)

    started = time.time()
    outputs: dict[str, str] = {}
    for name, proc, log in procs:
        timed_out = False
        try:
            proc.wait(timeout=max(1, args.timeout - (time.time() - started)))
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
            timed_out = True
        out = log.read_text(encoding="utf-8", errors="replace") if log.exists() else ""
        outputs[name] = out + ("\nTIMEOUT" if timed_out else "")
    print(f"logs: {log_dir}")

    ok = True
    results: dict[str, str] = {}
    for name, out in outputs.items():
        lines = out.splitlines()
        result = next((l for l in lines if l.startswith("RESULT ")), None)
        left = any(l.startswith("LEAVING") for l in lines)
        problems = [l for l in lines if any(m in l for m in PROBLEM_MARKERS)]
        status = "left early" if left else (result or "NO RESULT")
        print(f"{name:8s} {status}")
        for line in problems[:10]:
            print(f"    problem: {line}")
        if problems or "TIMEOUT" in out or (not left and result is None):
            ok = False
        if result and not left:
            results[name] = result
    if len(set(results.values())) > 1:
        print("MISMATCH: instances disagree on the final result")
        ok = False
    if not ok:
        for name, out in outputs.items():
            print(f"===== {name} (last 30 lines)")
            print("\n".join(out.splitlines()[-30:]))
    print("NETWORK TEST PASSED" if ok else "NETWORK TEST FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
