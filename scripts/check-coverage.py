#!/usr/bin/env python3
"""
Repo self-check:
  1. Every AZ-104 skill in docs/az104-skills-measured-2026-04-17.md appears in at
     least one lab's "Skills measured covered" table AND in docs/skills-coverage.md.
  2. Every relative markdown link resolves to a file in the repo.
  3. Screenshot checkpoint IDs are unique and match their lab number.

Usage:  python3 scripts/check-coverage.py        (exit code 1 on any problem)
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
problems = []

# ---------------------------------------------------------------- 1. skills
skills = [l[2:].strip() for l in (ROOT / "docs/az104-skills-measured-2026-04-17.md").read_text().splitlines()
          if l.startswith("- ")]
labs = sorted((ROOT / "labs").glob("*.md"))
coverage_doc = (ROOT / "docs/skills-coverage.md").read_text()

def covered_table(text):
    m = re.search(r"## Skills measured covered\n(.*?)\n---", text, re.S)
    return m.group(1) if m else ""

where = {s: [] for s in skills}
for lab in labs:
    table = covered_table(lab.read_text())
    for s in skills:
        if f"| {s} |" in table:
            where[s].append(lab.name[:2])

for s, found in where.items():
    if not found:
        problems.append(f"SKILL NOT IN ANY LAB TABLE: {s}")
    if f"| {s} |" not in coverage_doc:
        problems.append(f"SKILL NOT IN docs/skills-coverage.md: {s}")

# ---------------------------------------------------------------- 2. links
link_re = re.compile(r"\[[^\]]*\]\(([^)#\s]+)(?:#[^)]*)?\)")
for md in ROOT.rglob("*.md"):
    if ".git" in md.parts:
        continue
    for target in link_re.findall(md.read_text()):
        if re.match(r"^[a-z]+://", target) or target.startswith("mailto:"):
            continue
        if target.startswith("screenshots/") or "/screenshots/" in target:
            continue  # created by the learner
        resolved = (md.parent / target).resolve()
        if not resolved.exists():
            problems.append(f"BROKEN LINK in {md.relative_to(ROOT)}: {target}")

# ---------------------------------------------------------------- 3. checkpoints
seen = {}
cp_re = re.compile(r"Checkpoint (\d\d)-(\d\d)\*\* .*?`screenshots/lab-(\d\d)/(\d\d)-(\d\d)-")
for lab in labs:
    n = lab.name[:2]
    for m in cp_re.finditer(lab.read_text()):
        cid = f"{m.group(1)}-{m.group(2)}"
        if m.group(1) != n or m.group(3) != n or m.group(4) != n:
            problems.append(f"CHECKPOINT {cid} in {lab.name} has mismatched lab number")
        if f"{m.group(4)}-{m.group(5)}" != cid:
            problems.append(f"CHECKPOINT {cid} file name doesn't match its ID in {lab.name}")
        if cid in seen:
            problems.append(f"DUPLICATE CHECKPOINT {cid} in {lab.name} and {seen[cid]}")
        seen[cid] = lab.name

# ---------------------------------------------------------------- report
print(f"Skills: {sum(1 for v in where.values() if v)}/{len(skills)} covered by lab tables")
print(f"Labs scanned: {len(labs)}   Checkpoints: {len(seen)}")
if problems:
    print("\n".join(problems))
    sys.exit(1)
print("check-coverage: all good")
