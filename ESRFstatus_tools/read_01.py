#!/usr/bin/env python3
import requests
import json
import time

BASE_URL = "https://mstatus.esrf.fr/jyse/rest/player/designs/content"

def try_design(name_param: str):
    params = {"name": name_param}
    r = requests.get(BASE_URL, params=params)
    # Some servers use 200 with empty array when not found; some 404.
    if r.status_code != 200:
        return None

    try:
        data = r.json()
    except json.JSONDecodeError:
        return None

    if not data:
        return None

    # We expect an array with at least one entry with a "name" and "content"
    entry = data[0]
    return entry

def main():
    found = []
    for idx in range(1, 51):  # Try ID01..ID30
        blname = f"BM{idx:02d}"
        name_param = f"mstatus|{blname}"
        print(f"Trying {name_param} ...", end=" ", flush=True)

        entry = try_design(name_param)
        if entry:
            print("FOUND")
            found.append((name_param, entry["name"]))
        else:
            print("no design")

        time.sleep(0.2)  # politeness: 5 requests/sec

    print("\nDiscovered designs:")
    for name_param, design_name in found:
        print(f"{name_param} -> design name: {design_name}")

if __name__ == "__main__":
    main()