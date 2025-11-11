import gzip
import re

def parse_header_and_columns(data: bytes):
    # Read lines until &data
    offset = 0
    header_lines = []
    while True:
        nl = data.find(b'\n', offset)
        if nl == -1:
            raise RuntimeError("No newline found before end of file.")
        line = data[offset:nl].rstrip(b'\r')
        header_lines.append(line.decode('ascii', errors='replace'))
        offset = nl + 1
        if line.strip().lower().startswith(b'&data'):
            break

    # Extract columns with name and type
    columns = []
    for line in header_lines:
        if not line.lower().startswith("&column"):
            continue
        # Robustly extract name= and type= (quoted or unquoted)
        name = None
        ctype = None

        # name=... (may be quoted)
        m_name = re.search(r'name\s*=\s*("[^"]*"|[^,\s]+)', line, re.IGNORECASE)
        if m_name:
            name_val = m_name.group(1).strip()
            if name_val.startswith('"') and name_val.endswith('"'):
                name_val = name_val[1:-1]
            name = name_val

        m_type = re.search(r'type\s*=\s*("[^"]*"|[^,\s]+)', line, re.IGNORECASE)
        if m_type:
            type_val = m_type.group(1).strip().strip('"').lower()
            ctype = type_val

        columns.append({"name": name, "type": ctype})

    return offset, header_lines, columns

def read_little_int32(data, offset):
    return int.from_bytes(data[offset:offset+4], byteorder='little', signed=True)

def skip_numeric_column(data, offset, ctype, nrows):
    # Minimal size map for common SDDS types
    size_map = {
        "double": 8,
        "float": 4,
        "long": 4,
        "short": 2,
        "char": 1,
        "uchar": 1,
        "ulong": 4,
        "ushort": 2,
        "longlong": 8,
        "ulonglong": 8,
    }
    size = size_map.get(ctype)
    if size is None:
        # Unknown numeric type—best effort: print and abort
        raise RuntimeError(f"Unknown numeric column type: {ctype}")
    return offset + size * nrows

def read_string_column(data, offset, nrows):
    values = []
    for _ in range(nrows):
        strlen = read_little_int32(data, offset)
        offset += 4
        s = data[offset:offset+strlen]
        offset += strlen
        values.append(s.decode("utf-8", errors="replace"))
    return offset, values

def inspect_binary_gz(path):
    with gzip.open(path, "rb") as f:
        data = f.read()

    offset, header_lines, columns = parse_header_and_columns(data)

    print(f"Header lines: {len(header_lines)}")
    print("Columns (in file order):")
    for i, c in enumerate(columns):
        print(f"  [{i}] name={c['name']!r} type={c['type']!r}")

    # Skip whitespace
    while offset < len(data) and data[offset] in (0x20, 0x09, 0x0A, 0x0D):
        offset += 1

    # Read nrows (Int32, little-endian)
    nrows = read_little_int32(data, offset)
    offset += 4
    print(f"nrows = {nrows}")

    # Read columns column-by-column (SDDS binary layout)
    col_values = {}
    for c in columns:
        name = c["name"]
        ctype = c["type"]
        if ctype == "string":
            offset, vals = read_string_column(data, offset, nrows)
            col_values[name] = vals
            print(f"Read string column {name!r}: {len(vals)} entries")
        else:
            offset = skip_numeric_column(data, offset, ctype, nrows)
            print(f"Skipped numeric column {name!r} type={ctype!r}")

    # Show Description and ValueString values as read from raw binary
    desc = col_values.get("Description", [])
    vstr = col_values.get("ValueString", [])
    print("\nFirst 30 Description entries (raw vs trimmed):")
    for i, d in enumerate(desc[:30]):
        print(f"[{i:03d}] raw={d!r} trimmed={d.strip()!r}")

    print("\nFirst 30 ValueString entries:")
    for i, v in enumerate(vstr[:30]):
        print(f"[{i:03d}] {v!r}")

    # Cross-check matches
    labels_to_keep = {
        "Current","ScheduledMode","ActualMode","TopupState","InjOperation",
        "ShutterStatus","UpdateTime","RTFBStatus","OPSMessage1","OPSMessage2",
        "OPSMessage3","BM2ShutterClosed","BM7ShutterClosed","ID32ShutterClosed"
    }
    found = {d.strip() for d in desc if d.strip() in labels_to_keep}
    print("\nLabels found in raw parse:", sorted(found))
    print("Labels missing:", sorted(labels_to_keep - found))

# Run:
# inspect_binary_gz("mainStatus.sdds.gz")
