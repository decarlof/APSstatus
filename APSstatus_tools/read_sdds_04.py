import sdds

def main():
    input_file = "./mainStatus.sdds"  # or .gz if you prefer; sdds can handle gz
    sdds_obj = sdds.load(input_file)

    print(f"Loaded pages: {sdds_obj.loaded_pages}")
    print(f"Columns ({len(sdds_obj.columnName)}): {sdds_obj.columnName}")
    print(f"Arrays ({len(sdds_obj.arrayName)}): {sdds_obj.arrayName}")

    labels_to_keep = {
        "Current",
        "ScheduledMode",
        "ActualMode",
        "TopupState",
        "InjOperation",
        "ShutterStatus",
        "UpdateTime",
        "RTFBStatus",
        "OPSMessage1",
        "OPSMessage2",
        "OPSMessage3",
        "BM2ShutterClosed",
        "BM7ShutterClosed",
        "ID32ShutterClosed",
    }

    for page in range(sdds_obj.loaded_pages):
        print("\n================ PAGE", page, "================")

        # Show a preview of arrays (if present)
        for i, name in enumerate(sdds_obj.arrayName):
            value = sdds_obj.arrayData[i][page]
            print(f"Array '{name}': shape={getattr(value, 'shape', None)} len={len(value) if hasattr(value, '__len__') else 'n/a'}")

        # Find column indices
        try:
            desc_index = sdds_obj.columnName.index("Description")
            value_index = sdds_obj.columnName.index("ValueString")
        except ValueError as e:
            print("Error: Required columns not found:", e)
            continue

        descriptions = sdds_obj.columnData[desc_index][page]
        values = sdds_obj.columnData[value_index][page]

        print(f"Rows in Description: {len(descriptions)} | Rows in ValueString: {len(values)}")
        if len(descriptions) != len(values):
            print("Warning: Description and ValueString length mismatch!")

        # Dump EVERY description for inspection
        print("\nAll Description entries (raw vs trimmed, match flags):")
        found = set()
        for i, desc in enumerate(descriptions):
            trimmed = desc.strip()
            match_raw = desc in labels_to_keep
            match_trim = trimmed in labels_to_keep
            print(f"[{i:03d}] raw={desc!r} (len={len(desc)}) | trimmed={trimmed!r} | match_raw={match_raw} | match_trim={match_trim}")
            if match_trim:
                found.add(trimmed)

        missing = sorted(labels_to_keep - found)
        print("\nFound labels:", sorted(found))
        print("Missing labels:", missing)

        # Side-by-side output for the ones we want (using trimmed match)
        print("\nSelected key/value pairs:")
        for desc, val in zip(descriptions, values):
            trimmed = desc.strip()
            if trimmed in labels_to_keep:
                print(f"{trimmed} = {val}")

        # Optional: write a CSV for quick diff with Swift
        with open(f"sdds_page_{page}_desc_values.csv", "w", encoding="utf-8") as f:
            f.write("index,raw_description,trimmed_description,value\n")
            for i, (desc, val) in enumerate(zip(descriptions, values)):
                f.write(f"{i},{desc!r},{desc.strip()!r},{val!r}\n")

    # Optionally delete the SDDS object
    del sdds_obj

if __name__ == "__main__":
    main()
