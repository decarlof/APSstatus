#!/usr/bin/env python3
import argparse
import os
import time
from datetime import datetime
from io import BytesIO
from urllib.parse import urljoin

import requests
from bs4 import BeautifulSoup
from PIL import Image


PAGE_URL = "https://www3.aps.anl.gov/aod/blops/status/smallHistory.html"


def fetch_first_image_url(page_url: str, timeout=15) -> str:
    r = requests.get(page_url, timeout=timeout)
    r.raise_for_status()
    soup = BeautifulSoup(r.text, "html.parser")

    img = soup.find("img")
    if img is None or not img.get("src"):
        raise RuntimeError(f"No <img src=...> found on {page_url}")

    return urljoin(page_url, img["src"])


def download_image_bytes(img_url: str, timeout=30) -> bytes:
    r = requests.get(img_url, timeout=timeout)
    r.raise_for_status()
    return r.content


def save_as_png(img_bytes: bytes, out_png: str):
    im = Image.open(BytesIO(img_bytes))
    if im.mode not in ("RGB", "RGBA"):
        im = im.convert("RGBA")
    im.save(out_png, format="PNG")


# def _fmt_ts(epoch: float | None) -> str:
def _fmt_ts(epoch) -> str:
    if epoch is None:
        return "-"
    return datetime.fromtimestamp(epoch).strftime("%Y-%m-%d %H:%M:%S")


def print_status_table(out_path: str):
    out_path = os.path.abspath(out_path)
    directory = os.path.dirname(out_path)
    filename = os.path.basename(out_path)

    last_update = None
    size = None
    if os.path.exists(out_path):
        st = os.stat(out_path)
        last_update = st.st_mtime
        size = st.st_size

    print()
    print(f"Update: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"{'LAST_UPDATE':<20} {'SIZE':>12}  {'FILENAME':<25} {'DIRECTORY'}")
    print(f"{'-'*20} {'-'*12}  {'-'*25} {'-'*60}")
    print(f"{_fmt_ts(last_update):<20} {str(size if size is not None else '-'):>12}  "
          f"{filename:<25} {directory}")
    print(flush=True)


def main():
    parser = argparse.ArgumentParser()
    # removed --view
    parser.add_argument(
        "--out",
        default="/net/joulefs/coulomb_Public/docroot/tomolog/smallHistory.png",
        help="Output PNG file path (if a directory is given, smallHistory.png is used inside it).",
    )
    parser.add_argument("--period", type=int, default=60,
                        help="Update period in seconds.")
    args = parser.parse_args()

    out_path = args.out
    if os.path.isdir(out_path):
        out_path = os.path.join(out_path, "smallHistory.png")

    # print an initial table even before first successful fetch
    print_status_table(out_path)

    while True:
        try:
            img_url = fetch_first_image_url(PAGE_URL)
            img_bytes = download_image_bytes(img_url)
            save_as_png(img_bytes, out_path)
        except Exception as e:
            # keep looping; just report error on stderr-like output
            print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] ERROR: {e}", flush=True)

        # always print the status table after each cycle
        print_status_table(out_path)
        time.sleep(args.period)


if __name__ == "__main__":
    main()
