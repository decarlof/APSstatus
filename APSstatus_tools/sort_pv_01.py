#!/usr/bin/env python3
import argparse
import re
from typing import Optional, List

def pv_to_label(pv: str) -> Optional[str]:
    """
    Convert a PV like 'PA:13BM:STA_C_NO_ACCESS.VAL' to 'BM13StaCNoAccess'
    Rules:
      - Remove 'PA:' prefix
      - Convert '<num>BM:' -> 'BM<num>:' and '<num>ID:' -> 'ID<num>:'
      - Drop '.VAL'
      - Remove ':' and '_' and CamelCase each token
    """
    s = pv.strip()
    if not s:
        return None

    # Remove leading 'PA:'
    if s.startswith("PA:"):
        s = s[3:]

    # Swap "<num>(BM|ID):" to "(BM|ID)<num>:"
    m = re.match(r'^(\d+)(BM|ID):(.*)$', s, flags=re.IGNORECASE)
    if m:
        num, typ, rest = m.group(1), m.group(2).upper(), m.group(3)
        prefix = f"{typ}{num}"
    else:
        # Fallback: already in "BM<num>:" or "ID<num>:" form
        m2 = re.match(r'^(BM|ID)(\d+):(.*)$', s, flags=re.IGNORECASE)
        if not m2:
            return None
        typ, num, rest = m2.group(1).upper(), m2.group(2), m2.group(3)
        prefix = f"{typ}{num}"

    # Drop trailing '.VAL'
    rest = re.sub(r'\.VAL$', '', rest, flags=re.IGNORECASE)

    # Split on ':' or '_' and CamelCase tokens
    parts = [p for p in re.split(r'[_:]+', rest) if p]

    def cap_token(tok: str) -> str:
        return tok[:1].upper() + tok[1:].lower() if tok else ""

    label = prefix + "".join(cap_token(p) for p in parts)
    return label

def read_nonempty_lines(path: str) -> List[str]:
    with open(path, "r", encoding="utf-8") as f:
        return [line.rstrip() for line in f if line.strip()]

def main():
    ap = argparse.ArgumentParser(description="Generate labels for PV names and print aligned columns.")
    ap.add_argument("infile", help="Path to file with one PV per line (e.g., all_pv.txt)")
    ap.add_argument("-o", "--output", help="Output file (default: stdout)")
    ap.add_argument("--width", type=int, default=0, help="Left column width (default: auto)")
    args = ap.parse_args()

    pvs = read_nonempty_lines(args.infile)

    # Compute width for alignment (auto if not specified)
    maxlen = max((len(pv) for pv in pvs), default=0)
    width = args.width if args.width and args.width > 0 else maxlen + 2

    rows = []
    for pv in pvs:
        label = pv_to_label(pv) or "UNKNOWN"
        rows.append(f"{pv:<{width}} Label {label}")

    if args.output:
        with open(args.output, "w", encoding="utf-8") as out:
            out.write("\n".join(rows) + "\n")
    else:
        print("\n".join(rows))

if __name__ == "__main__":
    main()
