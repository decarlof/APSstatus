#!/usr/bin/env python3
import requests
import json
import sys

BASE_URL = "https://mstatus.esrf.fr/jyse/rest/player/designs/content"

def fetch_status(beamline_name: str):
    """
    Fetch design content for the given beamline, e.g. 'ID14'.
    """
    params = {"name": f"mstatus|{beamline_name}"}
    resp = requests.get(BASE_URL, params=params)
    resp.raise_for_status()
    data = resp.json()

    if not data:
        raise RuntimeError("Empty response from server")

    entry = data[0]
    # 'content' is itself a JSON-encoded string
    inner = json.loads(entry["content"])
    return inner

def extract_samples_as_pairs(inner_content: dict):
    """
    From the inner JSON object, extract the first entry in 'samples'
    as label/value pairs.
    """
    samples = inner_content.get("samples", {})
    if not samples:
        return []

    # Take the first sample value
    _, text = next(iter(samples.items()))

    # Split into non-empty lines
    lines = [line for line in text.splitlines() if line.strip()]

    pairs = []
    for line in lines:
        # Split on the first ':' to separate label from value
        if ":" in line:
            label, value = line.split(":", 1)
            label = label.strip()
            value = value.strip()
            pairs.append((label, value))
        else:
            # If no colon, treat entire line as a label-only
            pairs.append((line.strip(), ""))
    return pairs

def main():
    # Default beamline is ID14, but you can pass another name as argument
    beamline = sys.argv[1] if len(sys.argv) > 1 else "ID14"

    inner = fetch_status(beamline)
    pairs = extract_samples_as_pairs(inner)

    print(f"Beamline: {inner.get('title', beamline)}")
    for label, value in pairs:
        print(f"{label}: {value}")

if __name__ == "__main__":
    main()