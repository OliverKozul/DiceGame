"""End-to-end test of the table's options and of idle players, all headless over direct IP.

  1. Options and removal: the host picks options, a client sees them, another client is removed
     and refused when it tries again. The remaining client then goes idle: a bot takes its seat,
     it takes the seat back later, and the game finishes the same for everyone.
  2. An idle host: a bot takes over for the host too, so the table is never held up.

    python tools/lobbytest.py
"""
from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

DEFAULT_GODOT = os.environ.get(
    "GODOT", r"C:\Users\Oli\Downloads\win64-g46-s163-gs4171-editor\GodotSteam4.6.exe"
)
PROJECT = Path(__file__).resolve().parent.parent
TIMEOUT = 150
PROBLEMS = ("ERROR", "Request refused", "Autoplay request refused")


def run(name: str, players: dict[str, list[str]], log_dir: Path) -> dict[str, list[str]]:
    procs = []
    for i, (who, extra) in enumerate(players.items()):
        log = log_dir / f"{name}-{who}.log"
        cmd = [DEFAULT_GODOT, "--headless", "--path", str(PROJECT), "--log-file", str(log), "--",
               "--bot-delay=0.04", "--instant", f"--name={who}", f"--rejoin-file={log_dir / (name + who)}.cfg"] + extra
        procs.append((who, subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL), log))
        time.sleep(1.5 if i == 0 else 3.0)
    started = time.time()
    logs: dict[str, list[str]] = {}
    for who, proc, log in procs:
        try:
            proc.wait(timeout=max(1, TIMEOUT - (time.time() - started)))
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
            print(f"  {who} TIMED OUT")
        logs[who] = log.read_text(encoding="utf-8", errors="replace").splitlines() if log.exists() else []
    return logs


def has(lines: list[str], text: str) -> bool:
    return any(text in line for line in lines)


def result(lines: list[str]) -> str | None:
    return next((line for line in lines if line.startswith("RESULT ")), None)


def main() -> int:
    log_dir = Path(tempfile.mkdtemp(prefix="dicegame-lobbytest-"))
    print(f"logs: {log_dir}")
    failures: list[str] = []

    def check(ok: bool, what: str) -> None:
        print(f"  {'ok  ' if ok else 'FAIL'} {what}")
        if not ok:
            failures.append(what)

    print("1. Options, removal and an idle client")
    logs = run("options", {
        "Host": ["--autohost=enet", "--expect=2", "--bots=1", "--kick=Bad", "--difficulty=2", "--afk=1", "--turns=9",
                 "--seed=5", "--autoplay", "--quit-on-end"],
        "Bad": ["--autojoin=127.0.0.1", "--retry-after-kick", "--quit-on-end"],
        "Good": ["--autojoin=127.0.0.1", "--idle", "--return-at-turn=3", "--quit-on-end"],
    }, log_dir)
    check(has(logs["Host"], "KICKING Bad"), "the host removes a player")
    check(sum(has([line], "KICKED") for line in logs["Bad"]) == 2, "the removed player is told, and refused when trying again")
    check(has(logs["Good"], "ROOM difficulty=2 afk=1 turns=9"), "a client sees the options the host chose")
    check(has(logs["Good"], "AWAY at turn"), "a bot takes the seat of an idle client")
    check(has(logs["Good"], "TAKING THE SEAT BACK"), "the client takes its seat back")
    check(has(logs["Good"], '"turn":9'), "the game has the length the host chose")
    check(result(logs["Host"]) is not None and result(logs["Host"]) == result(logs["Good"]), "host and client agree on the result, recap included")
    check(has(logs["Good"], "ACHIEVEMENTS"), "the client works out its achievements")
    for who in ("Host", "Good"):
        check(not any(any(p in line for p in PROBLEMS) for line in logs[who]), f"{who} logged no errors")

    print("2. An idle host")
    logs = run("idlehost", {
        "Host": ["--autohost=enet", "--expect=2", "--bots=1", "--afk=1", "--turns=9", "--seed=6", "--idle", "--quit-on-end"],
        "Client": ["--autojoin=127.0.0.1", "--autoplay", "--quit-on-end"],
    }, log_dir)
    check(has(logs["Host"], "AWAY at turn"), "a bot takes the seat of an idle host")
    check(result(logs["Client"]) is not None and result(logs["Host"]) == result(logs["Client"]), "the game still finishes for everyone")
    for who in ("Host", "Client"):
        check(not any(any(p in line for p in PROBLEMS) for line in logs[who]), f"{who} logged no errors")

    if failures:
        print(f"LOBBY TEST FAILED ({len(failures)})")
        return 1
    print("LOBBY TEST PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
