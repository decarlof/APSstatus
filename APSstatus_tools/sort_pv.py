#!/usr/bin/env python3
import argparse

def read_list(path):
    """Return a list of non-empty, trimmed lines from a file."""
    items = []
    with open(path, 'r', encoding='utf-8') as f:
        for line in f:
            s = line.strip()
            if s:
                items.append(s)
    return items

def main():
    parser = argparse.ArgumentParser(
        description="Remove failed PVs from the full PV list."
    )
    parser.add_argument("all_pv", help="Path to all PVs file (one PV per line)")
    parser.add_argument("failed_pv", help="Path to failed PVs file (one PV per line)")
    parser.add_argument("-o", "--output", help="Output file (default: stdout)")
    args = parser.parse_args()

    all_pvs = read_list(args.all_pv)
    failed_pvs = set(read_list(args.failed_pv))  # set for fast lookup

    # Filter while preserving original order
    filtered = [pv for pv in all_pvs if pv not in failed_pvs]

    if args.output:
        with open(args.output, 'w', encoding='utf-8') as out:
            for pv in filtered:
                out.write(pv + "\n")
    else:
        for pv in filtered:
            print(pv)

if __name__ == "__main__":
    main()
