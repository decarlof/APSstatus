import sdds

def main():
    # Specify the input SDDS file.
    input_file = "./mainStatus.sdds"
    
    # Load the SDDS file into the SDDS object
    sdds_obj = sdds.load(input_file)
    
    for page in range(sdds_obj.loaded_pages):

        # Display array data for the current page
        for i, name in enumerate(sdds_obj.arrayName):
            value = sdds_obj.arrayData[i][page]
            print(f"  Array '{name}': {value}")
        

        # Find the indices of the two target columns
        desc_index = sdds_obj.columnName.index("Description")
        value_index = sdds_obj.columnName.index("ValueString")

        # Get the actual data arrays for the current page
        descriptions = sdds_obj.columnData[desc_index][page]
        values = sdds_obj.columnData[value_index][page]

        # Define which label keys to keep (no values)
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
            "ID32ShutterClosed"
        }

        print('###########################')
        print('###########################')
        # Print them side by side
        for desc, val in zip(descriptions, values):
            if desc in labels_to_keep:
                print(f"{desc} = {val}")
        print('###########################')
        print('###########################')



    # Opitonally delete the SDDS object
    del sdds_obj

if __name__ == "__main__":
    main()