#!/usr/bin/env python3
import requests
import json

BASE_URL = "https://mstatus.esrf.fr/jyse/rest/player/designs/content"

CANDIDATES = [
    "SR", "SRStatus", "SRstatus", "Machine", "MACHINE", "StorageRing", "SRCC"
]

def try_design(name_param: str):
    params = {"name": f"mstatus|{name_param}"}
    r = requests.get(BASE_URL, params=params)
    if r.status_code != 200:
        return None
    try:
        data = r.json()
    except json.JSONDecodeError:
        return None
    if not data:
        return None
    return data[0]

def main():
    for name in CANDIDATES:
        name_param = f"mstatus|{name}"
        print(f"Trying {name_param} ...", end=" ")
        entry = try_design(name)
        if entry:
            print("FOUND")
            print("  design name:", entry["name"])
            inner = json.loads(entry["content"])
            print("  title:", inner.get("title"))
            print()
        else:
            print("no design")

if __name__ == "__main__":
    main()
