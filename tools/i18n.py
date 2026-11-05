"""Translations: collect every text the player sees, keep the .po files in step, check them.

Text is found in
  - scripts: the first string literal of tr(), Loc.t(), Loc.msg(), Loc.n() and log_event();
  - scenes: text, placeholder_text and tooltip_text properties (Godot translates these itself);
  - content: display_name and description of trinkets, mobs and bosses.

    python tools/i18n.py update   # write Locale/messages.pot and merge it into every Locale/*.po
    python tools/i18n.py check    # exit 1 if a .po misses a translation or breaks a placeholder

A new language: copy messages.pot to Locale/<code>.po, translate it, add it to
project.godot (internationalization/locale/translations) and to Loc.LANGUAGES.

In a msgid, {name} placeholders must stay as they are (icon tokens such as {combat} too), and
BBCode tags such as [b]...[/b] must be kept, in any order the language needs.
"""
from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOCALE = ROOT / "Locale"
SKIP_DIRS = {".godot", ".git", "addons", "tests", "tools"}
CALL = re.compile(r"(?<![A-Za-z0-9_])(?:tr|Loc\.t|Loc\.msg|Loc\.n|log_event)\(\s*")
SCENE_PROPERTY = re.compile(r'^(?:text|placeholder_text|tooltip_text) = "((?:[^"\\]|\\.)*)"', re.M | re.S)
CONTENT_PROPERTY = re.compile(r'^(?:display_name|description) = "((?:[^"\\]|\\.)*)"', re.M | re.S)
PLACEHOLDER = re.compile(r"\{([a-z_0-9]+)\}")
TAG = re.compile(r"\[/?([a-z_]+)[^\]]*\]")
# Scene texts that are not words (addresses, placeholders replaced at runtime).
IGNORE = {"127.0.0.1"}
ESCAPES = {"n": "\n", "t": "\t", '"': '"', "'": "'", "\\": "\\", "r": "\r"}


@dataclass
class Entry:
    msgid: str
    refs: list[str] = field(default_factory=list)


def decode(raw: str) -> str:
    out, i = [], 0
    while i < len(raw):
        c = raw[i]
        if c == "\\" and i + 1 < len(raw):
            nxt = raw[i + 1]
            if nxt == "u" and i + 5 < len(raw):
                out.append(chr(int(raw[i + 2:i + 6], 16)))
                i += 6
                continue
            out.append(ESCAPES.get(nxt, nxt))
            i += 2
            continue
        out.append(c)
        i += 1
    return "".join(out)


def string_at(text: str, pos: int) -> str | None:
    """The GDScript string literal starting at pos, decoded, or None if there is none."""
    if text.startswith('"""', pos):
        end = text.find('"""', pos + 3)
        return decode(text[pos + 3:end]) if end >= 0 else None
    if pos < len(text) and text[pos] in "\"'":
        quote, i = text[pos], pos + 1
        while i < len(text) and text[i] != quote:
            i += 2 if text[i] == "\\" else 1
        return decode(text[pos + 1:i])
    return None


def collect() -> dict[str, Entry]:
    entries: dict[str, Entry] = {}

    def add(msgid: str, ref: str) -> None:
        if not msgid.strip() or msgid in IGNORE or not re.search(r"[A-Za-z]", msgid):
            return
        entries.setdefault(msgid, Entry(msgid)).refs.append(ref)

    def files(pattern: str):
        for path in sorted(ROOT.rglob(pattern)):
            if not SKIP_DIRS.intersection(path.relative_to(ROOT).parts):
                yield path

    for path in files("*.gd"):
        text = path.read_text(encoding="utf-8")
        for match in CALL.finditer(text):
            msgid = string_at(text, match.end())
            if msgid is not None:
                add(msgid, f"{path.relative_to(ROOT).as_posix()}:{text.count(chr(10), 0, match.start()) + 1}")
    for pattern, prop in (("*.tscn", SCENE_PROPERTY), ("*.tres", CONTENT_PROPERTY)):
        for path in files(pattern):
            text = path.read_text(encoding="utf-8")
            for match in prop.finditer(text):
                add(decode(match.group(1)), f"{path.relative_to(ROOT).as_posix()}:{text.count(chr(10), 0, match.start()) + 1}")
    return entries


# --- .po files -------------------------------------------------------------------

def po_quote(text: str) -> str:
    escaped = text.replace("\\", "\\\\").replace('"', '\\"').replace("\t", "\\t")
    lines = escaped.split("\n")
    if len(lines) == 1:
        return f'"{escaped}"'
    parts = [f'"{line}\\n"' for line in lines[:-1]]
    if lines[-1]:
        parts.append(f'"{lines[-1]}"')
    return '""\n' + "\n".join(parts)


def po_unquote(chunks: list[str]) -> str:
    return decode("".join(chunk[1:-1] for chunk in chunks))


def read_po(path: Path) -> tuple[str, dict[str, str]]:
    """The header block and msgid -> msgstr."""
    header, found = "", {}
    text = path.read_text(encoding="utf-8")
    blocks = re.split(r"\n\s*\n", text.strip())
    for block in blocks:
        msgid: list[str] = []
        msgstr: list[str] = []
        target = None
        for line in block.splitlines():
            line = line.strip()
            if line.startswith("msgid "):
                target = msgid
                line = line[6:]
            elif line.startswith("msgstr "):
                target = msgstr
                line = line[7:]
            elif not line.startswith('"'):
                target = None if line.startswith("#") else target
                continue
            if target is not None:
                target.append(line)
        if not msgid:
            continue
        key = po_unquote(msgid)
        if key == "":
            header = block
        else:
            found[key] = po_unquote(msgstr)
    return header, found


def write_po(path: Path, header: str, entries: dict[str, Entry], translations: dict[str, str]) -> None:
    out = [header.strip(), ""]
    for entry in entries.values():
        for ref in entry.refs[:4]:
            out.append(f"#: {ref}")
        out.append(f"msgid {po_quote(entry.msgid)}")
        out.append(f"msgstr {po_quote(translations.get(entry.msgid, ''))}")
        out.append("")
    path.write_text("\n".join(out), encoding="utf-8", newline="\n")


def pot_header() -> str:
    return 'msgid ""\nmsgstr ""\n"Content-Type: text/plain; charset=UTF-8\\n"\n"Content-Transfer-Encoding: 8-bit\\n"'


def update() -> int:
    entries = collect()
    LOCALE.mkdir(exist_ok=True)
    write_po(LOCALE / "messages.pot", pot_header(), entries, {})
    print(f"messages.pot: {len(entries)} texts")
    for po in sorted(LOCALE.glob("*.po")):
        header, old = read_po(po)
        dropped = [k for k in old if k not in entries]
        write_po(po, header or pot_header(), entries, old)
        missing = sum(1 for k in entries if not old.get(k))
        print(f"{po.name}: {missing} to translate, {len(dropped)} no longer used")
    return 0


def check() -> int:
    entries = collect()
    problems = 0
    for po in sorted(LOCALE.glob("*.po")):
        _, translations = read_po(po)
        for msgid in entries:
            text = translations.get(msgid, "")
            if not text:
                problems += 1
                print(f"{po.name}: missing: {msgid[:90]!r}")
                continue
            if set(PLACEHOLDER.findall(msgid)) != set(PLACEHOLDER.findall(text)):
                problems += 1
                print(f"{po.name}: placeholders differ: {msgid[:90]!r}")
            if sorted(TAG.findall(msgid)) != sorted(TAG.findall(text)):
                problems += 1
                print(f"{po.name}: BBCode tags differ: {msgid[:90]!r}")
        unused = [k for k in translations if k not in entries]
        if unused:
            print(f"{po.name}: {len(unused)} translations no longer used (run update)")
            problems += len(unused)
    print(f"{len(entries)} texts, {problems} problems")
    return 1 if problems else 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("command", choices=["update", "check"], nargs="?", default="check")
    args = ap.parse_args()
    return update() if args.command == "update" else check()


if __name__ == "__main__":
    sys.exit(main())
