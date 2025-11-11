import gzip
import sys

def read_i32_le(data, off):
    return int.from_bytes(data[off:off+4], 'little', signed=True)

def inspect_lengths(path):
    # Read entire file (gz or plain)
    with open(path, 'rb') as fh:
        head = fh.read(2)
    if head == b'\x1f\x8b':
        f = gzip.open(path, 'rb')
    else:
        f = open(path, 'rb')
    with f:
        data = f.read()

    # Read header lines until &data
    off = 0
    while True:
        nl = data.find(b'\n', off)
        if nl == -1:
            raise RuntimeError("No newline found before end of file.")
        line = data[off:nl].rstrip(b'\r')
        off = nl + 1
        if line.strip().lower().startswith(b'&data'):
            break

    # Skip whitespace before binary
    while off < len(data) and data[off] in (0x20, 0x09, 0x0A, 0x0D):
        off += 1

    # Read number of rows (little-endian Int32)
    nrows = read_i32_le(data, off)
    off += 4
    print("nrows =", nrows)

    # For your file (two string columns: Description, ValueString):
    # Column 0: Description
    cur = off
    desc = []
    for _ in range(nrows):
        L = read_i32_le(data, cur)
        cur += 4
        s = data[cur:cur+L].decode('utf-8', errors='replace')
        cur += L
        desc.append(s)

    # Column 1: ValueString
    val = []
    cur2 = cur
    for _ in range(nrows):
        L = read_i32_le(data, cur2)
        cur2 += 4
        s = data[cur2:cur2+L].decode('utf-8', errors='replace')
        cur2 += L
        val.append(s)

    print("\nFirst 10 Description entries (raw vs trimmed):")
    for i, d in enumerate(desc[:10]):
        print(f"[{i:03d}] raw={d!r} trimmed={d.strip()!r}")

    print("\nFirst 10 ValueString entries:")
    for i, v in enumerate(val[:10]):
        print(f"[{i:03d}] {v!r}")

if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else "mainStatus.sdds.gz"
    inspect_lengths(path)
