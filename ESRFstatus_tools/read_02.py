import json
import requests

BASE_URL = "https://mstatus.esrf.fr/jyse/rest/player/designs/content"

def fetch_design(beamline: str):
    resp = requests.get(BASE_URL, params={"name": f"mstatus|{beamline}"})
    resp.raise_for_status()
    data = resp.json()
    inner = json.loads(data[0]["content"])
    return inner

def collect_bindings(node, result):
    if isinstance(node, dict):
        # If there is a "bindings" section, record it
        if "bindings" in node and isinstance(node["bindings"], dict):
            result.append(node["bindings"])
        # Recurse into attributes and children/root/etc.
        for v in node.values():
            collect_bindings(v, result)
    elif isinstance(node, list):
        for v in node:
            collect_bindings(v, result)

def main():
    inner = fetch_design("ID14")
    bindings = []
    collect_bindings(inner, bindings)

    print("Found bindings:")
    for b in bindings:
        print(b)

    print("\nSamples keys:")
    for key, text in inner.get("samples", {}).items():
        print(f"- {key}")

if __name__ == "__main__":
    main()