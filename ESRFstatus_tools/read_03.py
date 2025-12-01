#!/usr/bin/env python3
import requests
import json
import time

BASE_URL = "https://mstatus.esrf.fr/jyse/rest/player/designs/content"

# Lists taken from your discovery runs
ID_BEAMLINES = [
    "ID01", "ID02", "ID03", "ID06", "ID08", "ID09", "ID10", "ID11",
    "ID12", "ID13", "ID14", "ID15", "ID16", "ID17", "ID18", "ID19",
    "ID20", "ID21", "ID22", "ID23", "ID24", "ID26", "ID27", "ID28",
    "ID29", "ID30", "ID31", "ID32"
]

BM_BEAMLINES = [
    "BM01", "BM02", "BM05", "BM07", "BM08", "BM14", "BM15", "BM16",
    "BM18", "BM20", "BM23", "BM25", "BM26", "BM28", "BM29", "BM30",
    "BM31", "BM32"
]


def fetch_design_content(beamline_name: str):
    """
    Fetch design content for the given beamline, e.g. 'ID14'.

    Returns the inner JSON object from the 'content' field, or None if not found.
    """
    params = {"name": f"mstatus|{beamline_name}"}
    r = requests.get(BASE_URL, params=params)
    if r.status_code != 200:
        return None

    try:
        outer = r.json()
    except json.JSONDecodeError:
        return None

    if not outer:
        return None

    entry = outer[0]
    inner = json.loads(entry["content"])
    return inner


def extract_samples_as_pairs(inner_content: dict):
    """
    From the inner JSON object, extract the first 'samples' entry
    and return it as a list of (label, value) pairs.
    """
    samples = inner_content.get("samples", {})
    if not samples:
        return []

    # Take the first sample string
    _, text = next(iter(samples.items()))

    # Split into non-empty lines
    lines = [line for line in text.splitlines() if line.strip()]

    pairs = []
    for line in lines:
        if ":" in line:
            label, value = line.split(":", 1)
            label = label.strip()
            value = value.strip()
            pairs.append((label, value))
        else:
            # Line without ':', treat as label only
            pairs.append((line.strip(), ""))

    return pairs


def print_status_for_beamline(beamline: str):
    inner = fetch_design_content(beamline)
    if inner is None:
        print(f"Beamline: {beamline}")
        print("Error: could not fetch design content\n")
        return

    pairs = extract_samples_as_pairs(inner)

    # Beamline header
    print(f"Beamline: {inner.get('title', beamline)}")
    for label, value in pairs:
        if value:
            print(f"{label}: {value}")
        else:
            print(label)
    print()  # blank line between beamlines


def main():
    # Print for all ID beamlines
    for bl in ID_BEAMLINES:
        print_status_for_beamline(bl)
        time.sleep(0.2)  # small delay to be polite to the server

    # Print for all BM beamlines
    for bl in BM_BEAMLINES:
        print_status_for_beamline(bl)
        time.sleep(0.2)


if __name__ == "__main__":
    main()