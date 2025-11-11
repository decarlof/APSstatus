import sdds

def main():
    # Specify the input SDDS file.
    input_file = "./mainStatus.sdds"
    
    # Load the SDDS file into the SDDS object
    sdds_obj = sdds.load(input_file)
    
    # Determine and display the file mode: Binary or ASCII
    if sdds_obj.mode == sdds.SDDS_BINARY:
        print("SDDS file mode: SDDS_BINARY")
    else:
        print("SDDS file mode: SDDS_ASCII")
    
    # Display the description text if available
    if sdds_obj.description[0]:
        print(f"SDDS file description text: {sdds_obj.description[0]}")
    
    # Display additional description contents if available
    if sdds_obj.description[1]:
        print(f"SDDS file description contents: {sdds_obj.description[1]}")
    
    # Check and print parameter definitions if any are present
    if sdds_obj.parameterName:
        print("\nParameters:")
        for i, definition in enumerate(sdds_obj.parameterDefinition):
            name = sdds_obj.parameterName[i]
            datatype = sdds.sdds_data_type_to_string(definition[4])
            units = definition[1]
            description = definition[2]
            print(f"  {name}")
            print(f"    Datatype: {datatype}", end="")
            if units:
                print(f", Units: {units}", end="")
            if description:
                print(f", Description: {description}", end="")
            print("")  # Newline for readability
    
    # Check and print array definitions if any are present
    if sdds_obj.arrayName:
        print("\nArrays:")
        for i, definition in enumerate(sdds_obj.arrayDefinition):
            name = sdds_obj.arrayName[i]
            datatype = sdds.sdds_data_type_to_string(definition[5])
            units = definition[1]
            description = definition[2]
            dimensions = definition[7]
            print(f"  {name}")
            print(f"    Datatype: {datatype}, Dimensions: {dimensions}", end="")
            if units:
                print(f", Units: {units}", end="")
            if description:
                print(f", Description: {description}", end="")
            print("")  # Newline for readability
    
    # Check and print column definitions if any are present
    if sdds_obj.columnName:
        print("\nColumns:")
        for i, definition in enumerate(sdds_obj.columnDefinition):
            name = sdds_obj.columnName[i]
            datatype = sdds.sdds_data_type_to_string(definition[4])
            units = definition[1]
            description = definition[2]
            print(f"  {name}")
            print(f"    Datatype: {datatype}", end="")
            if units:
                print(f", Units: {units}", end="")
            if description:
                print(f", Description: {description}", end="")
            print("")  # Newline for readability
    
    # Iterate through each loaded page and display parameter, array, and column data
    for page in range(sdds_obj.loaded_pages):
        print(f"\nPage: {page + 1}")
        
        # Display parameter data for the current page
        for i, name in enumerate(sdds_obj.parameterName):
            value = sdds_obj.parameterData[i][page]
            print(f"  Parameter '{name}': {value}")
        
        # Display array data for the current page
        for i, name in enumerate(sdds_obj.arrayName):
            value = sdds_obj.arrayData[i][page]
            print(f"  Array '{name}': {value}")
        
        # Display column data for the current page
        for i, name in enumerate(sdds_obj.columnName):
            value = sdds_obj.columnData[i][page]
            print(f"  Column '{name}': {value}")

    # Opitonally delete the SDDS object
    del sdds_obj

if __name__ == "__main__":
    main()