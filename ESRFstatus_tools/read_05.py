#!/usr/bin/env python3
import requests
import json

BASE_URL = "https://mstatus.esrf.fr/jyse/rest/player/designs/content"
FACADE_NAME = "mstatus|Facade_SMARTPHONE_Lite"


def fetch_design(name_param: str):
    params = {"name": name_param}
    resp = requests.get(BASE_URL, params=params)
    resp.raise_for_status()
    outer = resp.json()
    if not outer:
        raise RuntimeError("Empty response for design " + name_param)
    entry = outer[0]
    inner = json.loads(entry["content"])
    return inner


def extract_all_samples_pairs(inner_content: dict):
    """
    For a given design content, extract ALL samples entries and
    parse their text into (label, value) pairs.
    Returns a dict: { sample_key: [ (label, value), ... ], ... }
    """
    samples = inner_content.get("samples", {})
    result = {}

    for key, text in samples.items():
        # split into non-empty lines
        lines = [line for line in text.splitlines() if line.strip()]
        pairs = []
        for line in lines:
            if ":" in line:
                label, value = line.split(":", 1)
                label = label.strip()
                value = value.strip()
                pairs.append((label, value))
            else:
                pairs.append((line.strip(), ""))
        result[key] = pairs

    return result


def collect_bindings(node, result):
    """
    Traverse the design tree and collect all 'bindings' objects.
    """
    if isinstance(node, dict):
        if "bindings" in node and isinstance(node["bindings"], dict):
            result.append(node["bindings"])
        for v in node.values():
            collect_bindings(v, result)
    elif isinstance(node, list):
        for v in node:
            collect_bindings(v, result)


def main():
    inner = fetch_design(FACADE_NAME)
    title = inner.get("title", FACADE_NAME)
    print("Design title:", title)
    print()

    # Show all bindings (TANGO sources, etc.)
    bindings = []
    collect_bindings(inner, bindings)
    print("Bindings found in this design:")
    for b in bindings:
        print(b)
    print()

    # Parse all samples
    all_samples = extract_all_samples_pairs(inner)
    print("Samples parsed as label: value:")
    for sample_key, pairs in all_samples.items():
        print(f"\nSample key: {sample_key}")
        for label, value in pairs:
            if value:
                print(f"{label}: {value}")
            else:
                print(label)


if __name__ == "__main__":
    main()
