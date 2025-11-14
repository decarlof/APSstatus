import gzip
import re
import sys
import urllib.request

def read_i32_le(data, off):
    return int.from_bytes(data[off:off+4], 'little', signed=True)

def parse_header_defs(data):
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
    size_map = {
        "double": 8, "float": 4, "long": 4, "short": 2,
        "char": 1, "uchar": 1, "ulong": 4, "ushort": 2,
        "longlong": 8, "ulonglong": 8,
    }
    return size_map.get(ctype)

def inspect(path):

    url = path
    with urllib.request.urlopen(url) as resp:
        raw = resp.read()

    if raw[:2] == b'\x1f\x8b':
        data = gzip.decompress(raw)
    else:
        data = raw

    off, params, arrays, columns = parse_header_defs(data)
    print(f"Header parsed. Parameters: {len(params)}, Arrays: {len(arrays)}, Columns: {len(columns)}")
    print("Columns (file order):", [c["name"] for c in columns])

    while off < len(data) and data[off] in (0x20, 0x09, 0x0A, 0x0D):
        off += 1

    nrows = read_i32_le(data, off)
    off += 4
    print("nrows =", nrows)

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
            raw = data[off:off+sz]; off += sz
            print(f"  param {name!r} ({ctype}) bytes={raw.hex()}")

    print("\nReading arrays:")
    for a in arrays:
        name, ctype = a["name"], a["type"]
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

    print("\nReading table rows (row-major):")
    col_values = {c["name"]: [] for c in columns}
    for _ in range(nrows):
        for c in columns:
            name, ctype = c["name"], c["type"]
            if ctype == "string":
                L = read_i32_le(data, off); off += 4
                s = data[off:off+L].decode('utf-8', errors='replace'); off += L
                col_values[name].append(s)
            else:
                sz = size_of_numeric(ctype)
                if sz is None:
                    raise RuntimeError(f"Unknown column type {ctype!r} for {name!r}")
                raw = data[off:off+sz]; off += sz
                col_values[name].append(raw)

    desc = col_values.get("Description", [])
    vstr = col_values.get("ValueString", [])

    print("\nAll Description = ValueString pairs:")
    for i, (d, v) in enumerate(zip(desc, vstr)):
        print(f"[{i:03d}] {d.strip()} = {v}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Error: You must provide the URL to the SDDS file.")
        print("Usage: python read_sdds_09.py <url>")
        sys.exit(1)

    url = sys.argv[1]
    inspect(url)
