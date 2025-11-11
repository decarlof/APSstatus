#!/usr/bin/env python3
import struct
import numpy as np
import argparse
import sys

def read_sdds(filename):
    """
    Reads both ASCII and binary SDDS files into a dictionary.
    Supports standard SDDS numeric columns and parameters.
    """

    with open(filename, "rb") as f:
        # Read header lines until &data
        header_lines = []
        while True:
            line = f.readline().decode("utf-8", errors="ignore")
            if not line:
                raise ValueError("Missing &data section in SDDS file.")
            header_lines.append(line.strip())
            if line.strip().lower().startswith("&data"):
                break

        header = "\n".join(header_lines)

        # Parse columns and parameters
        columns = []
        parameters = []
        for line in header_lines:
            l = line.lower()
            if l.startswith("&column"):
                name = line.split("name=")[1].split(",")[0].strip()
                columns.append(name)
            elif l.startswith("&parameter"):
                name = line.split("name=")[1].split(",")[0].strip()
                parameters.append(name)

        # Detect mode
        mode = "ascii"
        for line in header_lines:
            if "mode=" in line.lower():
                mode = line.split("mode=")[1].split(",")[0].strip().lower()
                break

        if mode == "ascii":
            text = f.read().decode("utf-8", errors="ignore").strip().split()
            numbers = np.array([float(x) for x in text])
        elif mode == "binary":
            # Skip any whitespace or newlines before binary block
            while True:
                pos = f.tell()
                b = f.read(1)
                if not b or b not in b" \n\r\t":
                    f.seek(pos)
                    break

            # Read the SDDS binary preamble (int32: number of rows)
            try:
                nrows = struct.unpack("<i", f.read(4))[0]
            except Exception as e:
                raise ValueError(f"Cannot read number of rows: {e}")

            # Now read binary doubles for each column
            ncols = len(columns)
            expected = nrows * ncols
            numbers = np.frombuffer(f.read(expected * 8), dtype="<f8")
            if len(numbers) != expected:
                raise ValueError(
                    f"Binary size mismatch: expected {expected} doubles, got {len(numbers)}"
                )
        else:
            raise ValueError(f"Unsupported SDDS data mode: {mode}")

        # Organize into dictionary
        data = {}
        ncols = len(columns)
        if ncols > 0:
            nrows = len(numbers) // ncols
            arr = numbers.reshape((nrows, ncols))
            for i, col in enumerate(columns):
                data[col] = arr[:, i]

        # Placeholder for parameters
        for p in parameters:
            data[p] = None

        return data


def main():
    parser = argparse.ArgumentParser(description="Read SDDS (ASCII or binary) into dictionary.")
    parser.add_argument("filename", help="Path to SDDS file")
    parser.add_argument("--show", action="store_true", help="Print array values")
    args = parser.parse_args()

    try:
        data = read_sdds(args.filename)
    except Exception as e:
        print(f"Error reading {args.filename}: {e}")
        sys.exit(1)

    print(f"\nFile: {args.filename}")
    print("Keys:")
    for k in data:
        v = data[k]
        if isinstance(v, np.ndarray):
            print(f"  {k}: array of shape {v.shape}")
        else:
            print(f"  {k}: parameter")
    if args.show:
        print("\nData preview:")
        for k, v in data.items():
            print(f"{k}: {v}\n")

    print("Done.")


if __name__ == "__main__":
    main()
