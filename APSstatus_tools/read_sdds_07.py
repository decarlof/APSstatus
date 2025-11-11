import gzip
import re
import sys

def read_i32_le(data, off):
    return int.from_bytes(data[off:off+4], 'little', signed=True)

def parse_header_defs(data):
    """
    Parse header lines up to &data and return offset and lists of definitions:
    parameters, arrays, columns (each with name and type).
    """
    off = 0
    header_lines = []
    while True:
        nl = data.find(b'\n', off)
        if nl == -1:
            raise RuntimeError("No newline found before end of file while reading header.")
        line = data[off:nl].rstrip(b'\r')
        off = nl + 1
        header_lines.append(line.decode('ascii', errors='replace'))
        if line.strip().lower().startswith(b'&data'):
            break

    def extract_defs(prefix):
        defs = []
        for line in header_lines:
            if not line.lower().startswith(prefix):
                continue
            # name= (quoted or unquoted)
            m_name = re.search(r'name\s*=\s*("[^"]*"|[^,\s]+)', line, re.IGNORECASE)
            m_type = re.search(r'type\s*=\s*("[^"]*"|[^,\s]+)', line, re.IGNORECASE)
            name = None
            ctype = None
            if m_name:
                name = m_name.group(1).strip()
                if name.startswith('"') and name.endswith('"'):
                    name = name[1:-1]
            if m_type:
                ctype = m_type.group(1).strip().strip('"').lower()
            defs.append({"name": name, "type": ctype})
        return defs

    params  = extract_defs("&parameter")
    arrays  = extract_defs("&array")
    columns = extract_defs("&column")

    return off, params, arrays, columns

def size_of_numeric(ctype):
    # Minimal size map for common SDDS numeric types
    size_map = {
        "double": 8,
        "float": 4,
        "long": 4,       # SDDS long = 32-bit
        "short": 2,
        "char": 1,
        "uchar": 1,
        "ulong": 4,
        "ushort": 2,
        "longlong": 8,
        "ulonglong": 8,
    }
    return size_map.get(ctype)

def inspect(path):
    # Open .gz or plain file
    with open(path, 'rb') as fh:
        head = fh.read(2)
    f = gzip.open(path, 'rb') if head == b'\x1f\x8b' else open(path, 'rb')
    with f:
        data = f.read()

    off, params, arrays, columns = parse_header_defs(data)
    print(f"Header parsed. Parameters: {len(params)}, Arrays: {len(arrays)}, Columns: {len(columns)}")
    print("Columns (file order):", [c["name"] for c in columns])

    # Skip whitespace before binary block
    while off < len(data) and data[off] in (0x20, 0x09, 0x0A, 0x0D):
        off += 1

    # Read nrows (Int32 little-endian)
    nrows = read_i32_le(data, off)
    off += 4
    print("nrows =", nrows)

    # 1) Read/skip parameter values (in header order)
    #    SDDS writes parameter values before arrays and columns.
    print("\nReading parameters:")
    for p in params:
        name, ctype = p["name"], p["type"]
        if ctype == "string":
            L = read_i32_le(data, off); off += 4
            s = data[off:off+L].decode('utf-8', errors='replace'); off += L
            preview = s if len(s) < 80 else (s[:77] + "...")
            print(f"  param {name!r} (string) = {preview!r}")
        else:
            sz = size_of_numeric(ctype)
            if sz is None:
                raise RuntimeError(f"Unknown parameter type {ctype!r} for {name!r}")
            # Parameters are single values (not per-row)
            raw = data[off:off+sz]
            off += sz
            print(f"  param {name!r} ({ctype}) bytes={raw.hex()}")

    # 2) Read/skip arrays (if any)
    print("\nReading arrays:")
    for a in arrays:
        name, ctype = a["name"], a["type"]
        # Arrays start with Int32 element count
        nelems = read_i32_le(data, off); off += 4
        print(f"  array {name!r} type={ctype!r} count={nelems}")
        if ctype == "string":
            for i in range(nelems):
                L = read_i32_le(data, off); off += 4
                s = data[off:off+L].decode('utf-8', errors='replace'); off += L
                if i < 3:
                    print(f"    [{i}] {s!r}")
        else:
            sz = size_of_numeric(ctype)
            if sz is None:
                raise RuntimeError(f"Unknown array type {ctype!r} for {name!r}")
            off += sz * nelems

    # 3) Read columns column-by-column (SDDS column-major)
    print("\nReading columns:")
    col_values = {}
    for c in columns:
        name, ctype = c["name"], c["type"]
        if ctype == "string":
            vals = []
            for _ in range(nrows):
                L = read_i32_le(data, off); off += 4
                s = data[off:off+L].decode('utf-8', errors='replace'); off += L
                vals.append(s)
            col_values[name] = vals
            print(f"  column {name!r} (string) read {len(vals)} entries")
        else:
            sz = size_of_numeric(ctype)
            if sz is None:
                raise RuntimeError(f"Unknown column type {ctype!r} for {name!r}")
            # Skip numeric column data
            off += sz * nrows
            print(f"  column {name!r} ({ctype}) skipped {nrows} entries")

    # Sanity: show first few Description and ValueString entries
    desc = col_values.get("Description", [])
    vstr = col_values.get("ValueString", [])
    print("\nFirst 10 Description entries (raw vs trimmed):")
    for i, d in enumerate(desc[:10]):
        print(f"[{i:03d}] raw={d!r} trimmed={d.strip()!r}")

    print("\nFirst 10 ValueString entries:")
    for i, v in enumerate(vstr[:10]):
        print(f"[{i:03d}] {v!r}")

    # Cross-check matches for your selected labels
    labels_to_keep = {
        "Current","ScheduledMode","ActualMode","TopupState","InjOperation",
        "ShutterStatus","UpdateTime","RTFBStatus","OPSMessage1","OPSMessage2",
        "OPSMessage3","BM2ShutterClosed","BM7ShutterClosed","ID32ShutterClosed",
    }
    found = {d.strip() for d in desc if d.strip() in labels_to_keep}
    print("\nLabels found in Description:", sorted(found))
    print("Labels missing:", sorted(labels_to_keep - found))

if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else "mainStatus.sdds.gz"
    inspect(path)
