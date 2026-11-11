import asyncio
import os
from io import BytesIO
from pathlib import Path

from fastapi import FastAPI, HTTPException, Query, Request, Response
from fastapi.staticfiles import StaticFiles
from PIL import Image, ImageOps, UnidentifiedImageError
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest
from starlette.concurrency import run_in_threadpool

MAX_BYTES = 8 * 1024 * 1024
MAX_PIXELS = 16_000_000
FORMATS = ("JPEG", "PNG", "WEBP")
VERSION = os.getenv("APP_VERSION", "local")
REQUESTS = Counter("image_processing_requests", "Image processing requests", ["result"])
DURATION = Histogram("image_processing_duration_seconds", "Image processing duration")
app = FastAPI(title="Image Processing")
processing_slots = asyncio.Semaphore(2)

@app.get("/healthz")
def health():
    return {"status": "ok"}

@app.get("/api/version")
def version():
    return {"version": VERSION}

@app.get("/metrics", include_in_schema=False)
def metrics():
    return Response(generate_latest(), headers={"Content-Type": CONTENT_TYPE_LATEST})

def render_png(data: bytes, width: int | None, height: int | None, crop: bool) -> bytes:
    try:
        with Image.open(BytesIO(data), formats=FORMATS) as image:
            if image.width * image.height > MAX_PIXELS:
                raise HTTPException(413, "Images must be 16 megapixels or smaller.")
            if getattr(image, "is_animated", False):
                raise HTTPException(415, "Choose a still image.")
            with ImageOps.exif_transpose(image) as oriented:
                with oriented.convert("RGBA") as converted:
                    if width is not None and height is not None:
                        size = (width, height)
                        transform = ImageOps.fit if crop else ImageOps.contain
                        with transform(converted, size, method=Image.Resampling.LANCZOS) as resized:
                            return encode_png(resized)
                    return encode_png(converted)
    except Image.DecompressionBombError as error:
        raise HTTPException(413, "Images must be 16 megapixels or smaller.") from error
    except (UnidentifiedImageError, OSError, ValueError) as error:
        raise HTTPException(415, "Choose a valid JPEG, PNG, or WebP image.") from error

def encode_png(image: Image.Image) -> bytes:
    image.info.clear()
    with BytesIO() as output:
        image.save(output, format="PNG")
        return output.getvalue()

@app.post("/api/process", response_class=Response)
async def process(
    request: Request,
    width: int | None = Query(default=None, ge=1, le=4000),
    height: int | None = Query(default=None, ge=1, le=4000),
    crop: bool = False,
):
    if (width is None) != (height is None) or (crop and width is None):
        raise HTTPException(422, "Provide both width and height to resize or crop.")
    try:
        async with processing_slots:
            with DURATION.time():
                data = bytearray()
                async for chunk in request.stream():
                    if len(data) + len(chunk) > MAX_BYTES:
                        raise HTTPException(413, "Choose a file under 8 MiB.")
                    data.extend(chunk)
                result = await run_in_threadpool(render_png, bytes(data), width, height, crop)
    except HTTPException:
        REQUESTS.labels("rejected").inc()
        raise
    REQUESTS.labels("success").inc()
    return Response(result, media_type="image/png", headers={
        "Cache-Control": "no-store",
        "Content-Disposition": 'attachment; filename="processed.png"',
    })

frontend = Path(__file__).resolve().parents[1] / "frontend" / "dist"
if frontend.is_dir():
    app.mount("/", StaticFiles(directory=frontend, html=True), name="frontend")
