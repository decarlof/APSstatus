# pip install soliday.sdds
import sdds

def main():
    input_file = "./MpsData.sdds"  # or .gz if you prefer; sdds can handle gz
    sdds_obj = sdds.load(input_file)

    print(f"Loaded pages: {sdds_obj.loaded_pages}")
    print(f"Columns ({len(sdds_obj.columnName)}): {sdds_obj.columnName}")
    print(f"Arrays ({len(sdds_obj.arrayName)}): {sdds_obj.arrayName}")

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

        # Dump EVERY description/value pair
        print("\nAll Description entries with corresponding ValueString:")
        for i, (desc, val) in enumerate(zip(descriptions, values)):
            trimmed = desc.strip()
            print(f"[{i:03d}] {trimmed} = {val}")

        # Optional: write a CSV for inspection
        with open(f"sdds_page_{page}_desc_values.csv", "w", encoding="utf-8") as f:
            f.write("index,raw_description,trimmed_description,value\n")
            for i, (desc, val) in enumerate(zip(descriptions, values)):
                f.write(f"{i},{desc!r},{desc.strip()!r},{val!r}\n")

    # Optionally delete the SDDS object
    del sdds_obj

if __name__ == "__main__":
    main()
