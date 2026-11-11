"""Generate a bounded conversion workload for the course lab."""
import argparse
import collections
import random
import struct
import time
import urllib.request
import zlib
from concurrent.futures import ThreadPoolExecutor
from http.client import HTTPException
from urllib.parse import urlsplit

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def chunk(kind, data):
    checksum = zlib.crc32(kind + data)
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", checksum)


def sample_png(size=1200):
    pixels = random.Random(0).randbytes(size * size * 3)
    stride = size * 3
    scanlines = b"".join(
        b"\x00" + pixels[offset:offset + stride]
        for offset in range(0, len(pixels), stride)
    )
    header = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)
    return (
        PNG_SIGNATURE
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(scanlines, level=1))
        + chunk(b"IEND", b"")
    )


def send_conversions(url, payload, deadline):
    results = collections.Counter()
    while time.monotonic() < deadline:
        request = urllib.request.Request(
            url, data=payload, headers={"Content-Type": "image/png"}
        )
        try:
            with urllib.request.urlopen(request, timeout=10) as response:
                body = response.read()
                if (
                    response.headers.get_content_type() != "image/png"
                    or not body.startswith(PNG_SIGNATURE)
                ):
                    results["invalid PNG response"] += 1
                else:
                    results["success"] += 1
        except (OSError, HTTPException) as error:
            results[str(error)] += 1
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("base_url", help="Base URL of the lab's active Service")
    parser.add_argument("--seconds", type=int, default=125)
    parser.add_argument("--workers", type=int, default=4)
    args = parser.parse_args()
    parsed_url = urlsplit(args.base_url)
    if (
        parsed_url.scheme not in ("http", "https")
        or not parsed_url.hostname
        or parsed_url.query
        or parsed_url.fragment
    ):
        parser.error("base_url must be an HTTP or HTTPS URL")
    if not 1 <= args.seconds <= 300 or not 1 <= args.workers <= 8:
        parser.error("seconds must be 1–300 and workers must be 1–8")

    url = args.base_url.rstrip("/") + "/api/process"
    payload = sample_png()
    deadline = time.monotonic() + args.seconds
    print(f"Sending conversions to {url} with {args.workers} workers for {args.seconds}s.", flush=True)
    total = collections.Counter()
    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        tasks = [executor.submit(send_conversions, url, payload, deadline) for _ in range(args.workers)]
        for task in tasks:
            total.update(task.result())
    successes = total.pop("success", 0)
    print(f"{successes} successful conversions, {sum(total.values())} failures")
    for error, count in total.items():
        print(f"{count} × {error}")
    return 0 if successes and not total else 1


if __name__ == "__main__":
    raise SystemExit(main())
