"""Run the strategy simulator (tests/sim/strategy_sim.gd) in parallel and report which play
styles win, where their points come from and which trinkets and faces matter.

    python tools/strategy_sim.py                       # all experiments, default sizes
    python tools/strategy_sim.py --games 2000 --only mixed field
    python tools/strategy_sim.py --reads naive suspicious --field rational
    python tools/strategy_sim.py --reuse DIR           # re-analyse earlier results

Experiments:
    mixed   every seat draws a style from the pool (3-6 seats); the main balance check
    field   one seat plays each style, every other seat plays --field (default: BotBrain)
    mirror  every seat plays the same style (what the game feels like when everyone does X)

--reads sets how the strategy bots read declarations (BotBrain is always naive):
    naive       threats do not change what they choose: lying never pays against them
    gullible    they believe every declaration and react to declared attacks
    suspicious  they react, discounting each player's declarations by their record of lies
Each reads value is run on the same seeds, so the results compare like for like.

Speed: one game takes about 80 ms in GDScript; with the default 10 workers (below-normal priority)
10 000 games take about two minutes.
Profile with tests/sim/profile_sim.gd before and after changing the bots or the rules engine.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import pandas as pd

DEFAULT_GODOT = os.environ.get(
    "GODOT", r"C:\Users\Oli\Downloads\win64-g46-s163-gs4171-editor\GodotSteam4.6.exe"
)
PROJECT = Path(__file__).resolve().parent.parent
# Seven styles that span the strategy space; fewer styles means more samples per style.
POOL = ["honest", "rational", "farmer", "warlord", "builder", "miser", "boss_hunter"]
# Every style, for a full sweep (--pool all).
ALL_STYLES = ["baseline", "honest", "rational", "liar", "opportunist", "farmer", "warlord", "builder",
              "boss_hunter", "turtle", "miser", "schemer"]
SCRIPT = "res://tests/sim/strategy_sim.gd"


def run_chunk(godot: str, project: Path, out: Path, args: list[str]) -> Path:
    cmd = [godot, "--headless", "--path", str(project), "--script", SCRIPT, "--", *args, f"--out={out}"]
    # Below-normal priority, so the simulator never slows down what the user is doing.
    flags = getattr(subprocess, "BELOW_NORMAL_PRIORITY_CLASS", 0)
    proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", creationflags=flags)
    errors = [line for line in proc.stderr.splitlines() if line.strip()]
    if proc.returncode != 0 or errors:
        raise RuntimeError(f"{' '.join(args)} failed ({proc.returncode}):\n" + "\n".join(errors[:20]))
    return out


def plan_jobs(experiments: list[str], games: int, chunk: int, pool: list[str], reads: list[str],
              field: str) -> list[tuple[str, list[str]]]:
    """(name, args) for every chunk. Experiments get different seeds, reads values the same ones.
    Names are "<experiment>@<reads>_<first game>"."""
    jobs: list[tuple[str, list[str]]] = []

    def chunks(tag: str, base_seed: int, n: int, extra: list[str]) -> None:
        for r in reads:
            for start in range(0, n, chunk):
                count = min(chunk, n - start)
                jobs.append((f"{tag}@{r}_{start}", [*extra, f"--reads={r}", f"--games={count}",
                                                    f"--start={base_seed + start}"]))

    if "mixed" in experiments:
        chunks("mixed", 1_000_000, games, ["--mode=mixed", "--pool=" + ",".join(pool)])
    per_style = max(1, games // 4)
    for i, style in enumerate(pool):
        if "field" in experiments and style != field:
            chunks(f"field-{style}", 2_000_000 + i * 100_000, per_style, ["--mode=field", f"--hero={style}", f"--field={field}"])
        if "mirror" in experiments:
            chunks(f"mirror-{style}", 3_000_000 + i * 100_000, max(1, per_style // 2), ["--mode=mirror", f"--hero={style}"])
    return jobs


def load(directory: Path) -> pd.DataFrame:
    rows = []
    for path in sorted(directory.glob("*.jsonl")):
        experiment, reads = path.stem.rsplit("_", 1)[0].split("@")
        with path.open(encoding="utf-8") as f:
            for line in f:
                game = json.loads(line)
                finals = [p["final"] for p in game["players"]]
                mean = sum(finals) / len(finals)
                for p in game["players"]:
                    row = {k: v for k, v in p.items() if k not in ("bought", "final_faces", "trinkets", "mob_kills_by_tier")}
                    for tier, kills in enumerate(p.get("mob_kills_by_tier", [])):
                        row[f"mob_t{tier + 1}"] = kills
                    row.update(experiment=experiment, reads=reads, seed=game["seed"], seats=game["seats"],
                               win=int(p["rank"] == 0), expected=1.0 / game["seats"],
                               vs_table=p["final"] - mean, trinkets=p["trinkets"],
                               bought=p["bought"], final_faces=p["final_faces"],
                               boss_kills_game=len(game.get("boss_kills", [])))
                    rows.append(row)
    return pd.DataFrame(rows)


def style_table(df: pd.DataFrame) -> pd.DataFrame:
    g = df.groupby("style")
    t = pd.DataFrame({
        "n": g.size(),
        "win_idx": g.win.sum() / g.expected.sum(),
        "final": g.final.mean(),
        "vs_table": g.vs_table.mean(),
        "±95%": 1.96 * g.vs_table.std() / g.size() ** 0.5,
        "renown_end": g.renown.mean(),
        "honesty": g.honesty_renown.mean(),
        "mobs": g.mob_kills.mean(),
        "boss": g.boss_kills.mean(),
        "KO+": g.kos_dealt.mean(),
        "KO-": g.kos_taken.mean(),
        "kept%": 100 * g.kept.sum() / (g.kept.sum() + g.broke.sum()),
        "pvp_dmg": g.pvp_damage.mean(),
        "dmg_in": g.damage_taken.mean(),
        "gold_left": g.gold.mean(),
        "dice": g.dice.mean(),
        "faces": g.faces_bought.mean(),
        "upgr": g.upgrades.mean() if "upgrades" in df else 0.0,
        "rn_buy": g.renown_bought.mean() if "renown_bought" in df else 0.0,
    })
    return t.sort_values("vs_table", ascending=False)


def score_sources(df: pd.DataFrame) -> pd.DataFrame:
    """Average points per player from each source (renown counts what is left at the end)."""
    g = df.groupby("style")
    return pd.DataFrame({
        "renown_left": g.renown.mean(),
        "of it stolen": g.renown_stolen.mean() if "renown_stolen" in df else 0.0,
        "lost to theft": -g.renown_lost.mean() if "renown_lost" in df else 0.0,
        "mobs(+1)": g.mob_kills.mean(),
        "boss(+2)": 2 * g.boss_kills.mean(),
        "KO dealt(+2)": 2 * g.kos_dealt.mean(),
        "KO taken(-1)": -g.kos_taken.mean(),
        "final": g.final.mean(),
    }).sort_values("final", ascending=False)


def trinket_table(df: pd.DataFrame) -> pd.DataFrame:
    rows = []
    names = sorted({t for ts in df.trinkets for t in ts})
    for name in names:
        has = df.trinkets.map(lambda ts, n=name: n in ts)
        sub = df[has]
        rest = df[~has]
        rows.append({"trinket": name, "owners%": 100 * has.mean(),
                     "win_idx_with": sub.win.sum() / sub.expected.sum(),
                     "win_idx_without": rest.win.sum() / rest.expected.sum(),
                     "vs_table_with": sub.vs_table.mean()})
    return pd.DataFrame(rows).set_index("trinket").sort_values("win_idx_with", ascending=False)


def bought_table(df: pd.DataFrame) -> pd.DataFrame:
    """Per face bought: how often, and the win index of players who bought at least one."""
    counts: dict[str, int] = {}
    for b in df.bought:
        for k, v in b.items():
            counts[k] = counts.get(k, 0) + v
    rows = []
    for face, total in counts.items():
        has = df.bought.map(lambda b, f=face: f in b)
        sub = df[has]
        rows.append({"face": face, "bought_per_game": total / df.seed.nunique(), "buyers%": 100 * has.mean(),
                     "win_idx_buyers": sub.win.sum() / sub.expected.sum()})
    return pd.DataFrame(rows).set_index("face").sort_values("win_idx_buyers", ascending=False)


def game_table(df: pd.DataFrame) -> pd.DataFrame:
    """Per game, summed over the table: what a game of each mirror style looks like."""
    games = df.groupby(["experiment", "seed"]).agg(
        seats=("seats", "first"), kos=("kos_taken", "sum"), mobs=("mob_kills", "sum"),
        boss_kills=("boss_kills", "max"), pvp_attacks=("pvp_attacks", "sum"),
        winner=("final", "max"), mean=("final", "mean"), spread=("final", lambda s: s.max() - s.min()))
    return games.groupby("experiment").mean(numeric_only=True)


def game_summary(df: pd.DataFrame) -> pd.Series:
    """What an average game looks like (per game unless it says per player)."""
    games = df.groupby(["experiment", "seed"])
    per_game = games.agg(seats=("seats", "first"), winner=("final", "max"), mean=("final", "mean"),
                         kos=("kos_taken", "sum"), boss_kills=("boss_kills_game", "first"),
                         mob_kills=("mob_kills", "sum"), stolen=("renown_stolen", "sum"),
                         auctions=("auctions_won", "sum"), pvp_attacks=("pvp_attacks", "sum"))
    out = per_game.mean(numeric_only=True)
    for col in ("mob_t1", "mob_t2", "mob_t3"):
        if col in df:
            out[f"{col} (per game)"] = games[col].sum().mean()
    for col, label in (("renown", "renown left"), ("honesty_renown", "renown from oaths"), ("gold", "gold left"),
                       ("min_hp", "lowest HP"), ("hp", "HP at end"), ("rests", "rests"), ("upgrades", "upgrades"),
                       ("renown_bought", "renown bought"), ("faces_bought", "faces bought"), ("dice", "dice"),
                       ("refreshes", "refreshes"), ("damage_taken", "damage taken"), ("score", "trophies")):
        if col in df:
            out[f"{label} (per player)"] = df[col].mean()
    return out


def report(df: pd.DataFrame) -> None:
    pd.set_option("display.width", 220)
    pd.set_option("display.max_columns", 40)
    pd.set_option("display.float_format", lambda v: f"{v:.2f}")
    for reads, group in df.groupby("reads", sort=False):
        print(f"\n\n######## strategy bots read the table: {reads.upper()} ########")
        report_group(group)


def report_group(df: pd.DataFrame) -> None:
    mixed = df[df.experiment == "mixed"]
    if not mixed.empty:
        print(f"\n=== MIXED tables: {mixed.seed.nunique()} games; win_idx 1.00 = fair share ===")
        print(style_table(mixed).to_string())
        print("\nAverage game:")
        print(game_summary(mixed).to_string())
        print("\nScore sources (points per player):")
        print(score_sources(mixed).to_string())
        print("\nWin index by seats (rows) and style:")
        piv = mixed.groupby(["seats", "style"]).apply(lambda s: s.win.sum() / s.expected.sum(), include_groups=False)
        print(piv.unstack().to_string())
        print("\nTrinkets (mixed tables):")
        print(trinket_table(mixed).to_string())
        print("\nFaces bought (mixed tables):")
        print(bought_table(mixed).to_string())
        cols = ["win", "initiative_rank", "honesty_renown", "mob_kills", "kos_dealt", "lied_attacks", "dice", "faces_bought", "gold"]
        r = mixed[cols].corr()["win"]
        print("\nCorrelation with winning:\n" + r.drop("win").to_string())

    field = df[df.experiment.str.startswith("field-")]
    if not field.empty:
        heroes = field[field.experiment.str.slice(6) == field["style"]]
        print("\n=== FIELD: one seat of each style vs a field of one style ===")
        print(style_table(heroes).to_string())

    mirror = df[df.experiment.str.startswith("mirror-")]
    if not mirror.empty:
        print("\n=== MIRROR: every seat the same style (per game totals) ===")
        print(game_table(mirror).to_string())


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--godot", default=DEFAULT_GODOT)
    ap.add_argument("--games", type=int, default=1200,
                    help="mixed games (1200 with the default pool: about ±0.4 points per style); "
                         "field/mirror use a quarter/eighth per style")
    ap.add_argument("--chunk", type=int, default=250, help="games per Godot process (startup is ~0.8 s)")
    # 10 of 16 threads by default: leaves the machine usable for other work.
    ap.add_argument("--workers", type=int, default=min(10, max(1, (os.cpu_count() or 4) - 2)))
    ap.add_argument("--only", nargs="*", default=["mixed"], choices=["mixed", "field", "mirror"])
    ap.add_argument("--pool", default=",".join(POOL), help='comma-separated styles, or "all"')
    ap.add_argument("--reads", nargs="+", default=["suspicious"], choices=["naive", "gullible", "suspicious"])
    ap.add_argument("--field", default="baseline", help="style of the other seats in field games")
    ap.add_argument("--project", type=Path, default=PROJECT, help="project to simulate (e.g. a worktree with a rules variant)")
    ap.add_argument("--out", type=Path, help="directory for the JSONL results (default: a temp dir)")
    ap.add_argument("--reuse", type=Path, help="analyse an earlier results directory without running")
    args = ap.parse_args()

    if args.reuse:
        report(load(args.reuse))
        return 0
    out = args.out or Path(tempfile.mkdtemp(prefix="dicegame_sim_"))
    out.mkdir(parents=True, exist_ok=True)
    pool = ALL_STYLES if args.pool == "all" else args.pool.split(",")
    jobs = plan_jobs(args.only, args.games, args.chunk, pool, args.reads, args.field)
    # Longest first, so no worker is left with a big chunk at the end.
    jobs.sort(key=lambda job: -int(next(a for a in job[1] if a.startswith("--games=")).split("=")[1]))
    started = time.time()
    with ThreadPoolExecutor(args.workers) as ex:
        futures = [ex.submit(run_chunk, args.godot, args.project, out / f"{name}.jsonl", job_args) for name, job_args in jobs]
        for i, f in enumerate(futures, 1):
            f.result()
            if i % 10 == 0 or i == len(futures):
                print(f"{i}/{len(futures)} chunks", file=sys.stderr, flush=True)
    total = sum(int(next(a for a in job_args if a.startswith("--games=")).split("=")[1]) for _, job_args in jobs)
    elapsed = time.time() - started
    print(f"\nran {total} games in {len(jobs)} chunks in {elapsed:.0f}s ({total / elapsed:.0f} games/s) -> {out}",
          file=sys.stderr)
    report(load(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
