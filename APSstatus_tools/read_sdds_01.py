import sdds

def main():
    # Load the SDDS file
    input_file = "./mainStatus.sdds"
    sdds_obj = sdds.load(input_file)

    # Get Description and ValueString arrays for the first page
    descriptions = sdds_obj.columnData[sdds_obj.columnName.index('Description')][0]
    values = sdds_obj.columnData[sdds_obj.columnName.index('ValueString')][0]

    # Create a list of items to print in the desired order
    selected_names = ['Current']  # first item
    selected_names += list(descriptions[:10])  # first 10 items
    selected_names += ['BM2ShutterClosed', 'BM7ShutterClosed', 'ID32ShutterClosed']

    # Filter out duplicates and ensure the names exist in the descriptions
    final_names = []
    for name in selected_names:
        if name in descriptions and name not in final_names:
            final_names.append(name)

    # Print them
    for name in final_names:
        idx = descriptions.index(name)
        print(f"{descriptions[idx]} - {values[idx]}")

if __name__ == "__main__":
    main()
