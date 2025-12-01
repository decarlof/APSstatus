#!/usr/bin/env python3
import requests
import json

BASE_URL = "https://mstatus.esrf.fr/jyse/rest/player/designs/content"
FACADE_NAME = "mstatus|Facade_SMARTPHONE_Lite"

# Map Tango sample keys (suffix part) to human-readable labels
LABEL_MAP = {
    "Current": "Beam Current",
    "Filling_mode": "Filling mode",
    "Lifetime": "Lifetime",
    "EmittanceH": "Horizontal emittance",
    "EmittanceV": "Vertical emittance",
    "AvgPress": "Average pressure",
    "DateandTime_str": "Date/time",
    "Since_mesg": "Since",
    "injector_current": "Injector current",
}


def fetch_facade():
    params = {"name": FACADE_NAME}
    resp = requests.get(BASE_URL, params=params)
    resp.raise_for_status()
    outer = resp.json()
    if not outer:
        raise RuntimeError("Empty response for design " + FACADE_NAME)
    entry = outer[0]
    inner = json.loads(entry["content"])
    return inner


def normalize_label_from_key(sample_key: str) -> str:
    """
    Given a sample key like
      'TANGO|tangorest02.esrf.fr/10000|sys/mcs/facade/Current'
    return a human-friendly label, using LABEL_MAP if possible.
    """
    # Take the Tango attribute name part after the last '/'
    suffix = sample_key.split("/")[-1]
    return LABEL_MAP.get(suffix, suffix)


def extract_samples(inner_content: dict):
    """
    Extract all samples as (label, value) pairs.

    Handles both string samples (multi-line status text) and numeric samples.
    """
    samples = inner_content.get("samples", {})
    result = []

    for sample_key, value in samples.items():
        label_base = normalize_label_from_key(sample_key)

        # If value is numeric, just output one pair
        if isinstance(value, (int, float)):
            result.append((label_base, str(value)))
            continue

        # Otherwise, treat as string
        if isinstance(value, str):
            lines = [line for line in value.splitlines() if line.strip()]
            # If it's a multi-line status block (with ":" inside),
            # split each line into label: value if possible
            # Otherwise, treat the full line as value under label_base
            if any(":" in line for line in lines):
                for line in lines:
                    if ":" in line:
                        lab, val = line.split(":", 1)
                        lab = lab.strip()
                        val = val.strip()
                        # Use line's own label
                        result.append((lab, val))
                    else:
                        result.append((label_base, line.strip()))
            else:
                # Single value-like string (no ':'), use base label
                combined = " ".join(lines)
                result.append((label_base, combined))
        # For any other type, just stringify
        else:
            result.append((label_base, str(value)))

    return result


def main():
    inner = fetch_facade()
    title = inner.get("title", "Facade_SMARTPHONE_Lite")
    print("Design title:", title)

    pairs = extract_samples(inner)

    # Filter only the main SR parameters if you like
    wanted = {
        "Beam Current",
        "Filling mode",
        "Lifetime",
        "Horizontal emittance",
        "Vertical emittance",
        "Average pressure",
    }

    print()
    print("Storage Ring parameters (label: value):")
    for label, value in pairs:
        if not wanted or label in wanted:
            print(f"{label}: {value}")


if __name__ == "__main__":
    main()
