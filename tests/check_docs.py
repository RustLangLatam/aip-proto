"""Check that the coverage tables and item counts in the docs match the checklist and api-linter.

Usage: python3 tests/check_docs.py <api-linter binary>
Exit 0 when consistent, 1 with a list of mismatches otherwise.
"""
import collections
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CHECKLIST = ROOT / "skills/aip-audit/references/manual-review.md"
REPORT = ROOT / "docs/TECHNICAL_REPORT.md"
README = ROOT / "README.md"


def linter_rule_counts(binary):
    out = subprocess.run([binary, "--list-rules"], capture_output=True, text=True, check=True).stdout
    return collections.Counter(str(int(n)) for n in re.findall(r"core::(\d+)::", out))


def checklist_items():
    """Map AIP number -> item ids that link it."""
    items = collections.defaultdict(list)
    for line in CHECKLIST.read_text().splitlines():
        m = re.match(r"\| ([RMFEC]\d+[a-z]?) \|(.*?)\|", line)
        if m:
            for aip in re.findall(r"google\.aip\.dev/(\d+)", m.group(2)):
                items[aip].append(m.group(1))
    return items


def expand(nums):
    out = []
    for part in nums.split("/"):
        if "–" in part:
            a, b = map(int, part.split("–"))
            out += [str(x) for x in range(a, b + 1)]
        else:
            out.append(part)
    return out


def check_coverage_map(rules, items, errors):
    cmap = CHECKLIST.read_text().split("## AIP coverage map", 1)[1]
    for nums, mark in re.findall(r"(\d+(?:[–/]\d+)*) (L\+M|L|M|—)", cmap):
        for n in expand(nums):
            want = ("L" if n in rules else "") + ("+M" if n in rules and n in items else "M" if n in items else "")
            if (want or "—") != mark:
                errors.append(f"coverage map: AIP-{n} marked {mark}, expected {want or '—'}")


def check_appendix(rules, items, errors):
    appendix = REPORT.read_text().split("## Appendix A", 1)[1]
    seen = set()
    for line in appendix.splitlines():
        cols = line.split("|")
        if len(cols) != 7 or "Title" in cols[3]:
            continue
        aips = re.findall(r"\d+", cols[2])
        counts = re.findall(r"\d+", cols[4]) or ["0"]
        if len(counts) == 1 and len(aips) > 1:
            counts *= len(aips)
        for aip, count in zip(aips, counts):
            seen.add(aip)
            if str(rules.get(aip, 0)) != count:
                errors.append(f"appendix: AIP-{aip} lists {count} rules, linter has {rules.get(aip, 0)}")
        if len(aips) == 1 and items.get(aips[0]):
            listed = set(re.findall(r"[RMFEC]\d+[a-z]?", cols[5]))
            if listed != set(items[aips[0]]):
                errors.append(f"appendix: AIP-{aips[0]} items {sorted(listed)}, checklist has {sorted(items[aips[0]])}")
    missing = set(rules) - seen
    if missing:
        errors.append(f"appendix: linted AIPs missing: {sorted(missing, key=int)}")


def check_counts(rules, items, errors):
    n_items = sum(1 for l in CHECKLIST.read_text().splitlines() if re.match(r"\| [RMFEC]\d+[a-z]? \|", l))
    n_aips = len(items)
    n_rules = sum(rules.values())
    for path in (README, REPORT):
        text = path.read_text()
        for found in re.findall(r"(\d+)-item checklist", text):
            if int(found) != n_items:
                errors.append(f"{path.name}: says {found}-item checklist, checklist has {n_items}")
        for a, b in re.findall(r"(\d+) items link(?:ing)? (\d+) AIPs", text):
            if (int(a), int(b)) != (n_items, n_aips):
                errors.append(f"{path.name}: says {a} items / {b} AIPs, actual {n_items} / {n_aips}")
        for found in re.findall(r"(?<![\d.])(\d+) `core` rules", text):
            if int(found) != n_rules:
                errors.append(f"{path.name}: says {found} core rules, linter has {n_rules}")


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    rules, items, errors = linter_rule_counts(sys.argv[1]), checklist_items(), []
    check_coverage_map(rules, items, errors)
    check_appendix(rules, items, errors)
    check_counts(rules, items, errors)
    for e in errors:
        print("FAIL:", e)
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
