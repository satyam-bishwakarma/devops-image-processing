"""Exercise the application's public HTTP endpoints against a running instance."""
import os
import time
from io import BytesIO
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from PIL import Image

BASE_URL = os.getenv("SMOKE_URL", "http://127.0.0.1:8000").rstrip("/")

def request(path, data=None):
    return urlopen(Request(BASE_URL + path, data=data), timeout=10)

for attempt in range(30):
    try:
        with request("/healthz") as response:
            assert response.status == 200
        break
    except URLError:
        if attempt == 29:
            raise
        time.sleep(1)

with request("/") as response:
    assert b"<title>Image Processing</title>" in response.read()

with BytesIO() as input_file:
    with Image.new("RGB", (16, 12), (28, 112, 84)) as sample:
        sample.save(input_file, format="JPEG")
    with request("/api/process", input_file.getvalue()) as response:
        assert response.headers.get_content_type() == "image/png"
        with Image.open(BytesIO(response.read())) as result:
            assert result.format == "PNG" and result.size == (16, 12)
            result.load()

for payload, status in ((b"invalid image", 415), (b"x" * (8 * 1024 * 1024 + 1), 413)):
    try:
        with request("/api/process", payload):
            raise AssertionError(f"Expected HTTP {status}")
    except HTTPError as error:
        assert error.code == status, error.code
        error.close()

with request("/api/version") as response:
    assert b'"version"' in response.read()

with request("/metrics") as response:
    metrics = response.read()
    assert b'image_processing_requests_total{result="success"}' in metrics
    assert b'image_processing_requests_total{result="rejected"}' in metrics

print("Smoke checks passed: UI, conversion, validation, version, metrics.")
