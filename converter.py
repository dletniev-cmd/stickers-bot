import asyncio
import logging
import os

import imageio_ffmpeg

logger = logging.getLogger(__name__)

_FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()

MAX_SIZE_BYTES       = 256 * 1024
MAX_STICKER_DURATION = 8.0

# Видео / кружки → круглая маска
_VF_VIDEO = (
    "scale=512:512:force_original_aspect_ratio=increase,"
    "crop=512:512,"
    "format=rgba,"
    "geq="
    "r='r(X,Y)':"
    "g='g(X,Y)':"
    "b='b(X,Y)':"
    "a='255*lt(hypot(X-W/2,Y-H/2),W/2)',"
    "format=yuva420p"
)

# Фото → просто скейл, без прозрачности (статичный webp)
_VF_PHOTO_WEBP = (
    "scale=512:512:force_original_aspect_ratio=increase,"
    "crop=512:512"
)


async def convert_photo_to_webp(input_path: str, output_path: str) -> bool:
    """Конвертирует фото в статичный webp стикер (512x512)."""
    cmd = [
        _FFMPEG, "-y",
        "-i", input_path,
        "-vf", _VF_PHOTO_WEBP,
        "-vframes", "1",
        "-q:v", "80",
        output_path,
    ]
    proc = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    _, stderr = await proc.communicate()
    if proc.returncode != 0:
        logger.error("ffmpeg photo error:\n%s", stderr.decode(errors="replace"))
        return False
    size = os.path.getsize(output_path)
    logger.info("photo webp size: %d bytes", size)
    return size <= MAX_SIZE_BYTES


async def _run_ffmpeg(
    input_path: str,
    output_path: str,
    crf: int,
    start_time: float = 0.0,
    clip_duration: float = MAX_STICKER_DURATION,
) -> bool:
    cmd = [_FFMPEG, "-y"]

    if start_time > 0.0:
        cmd += ["-ss", f"{start_time:.3f}"]

    cmd += [
        "-i", input_path,
        "-vf", _VF_VIDEO,
        "-c:v", "libvpx-vp9",
        "-pix_fmt", "yuva420p",
        "-b:v", "0",
        "-crf", str(crf),
        "-r", "30",
        "-auto-alt-ref", "0",
        "-row-mt", "1",
        "-an",
        "-t", f"{clip_duration:.3f}",
        output_path,
    ]

    proc = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    _, stderr = await proc.communicate()

    if proc.returncode != 0:
        logger.error("ffmpeg error (crf=%d):\n%s", crf, stderr.decode(errors="replace"))
        return False
    return True


async def convert_to_sticker(
    input_path: str,
    output_path: str,
    start_time: float = 0.0,
    clip_duration: float = MAX_STICKER_DURATION,
) -> bool:
    for crf in [33, 38, 43, 48, 55, 63]:
        ok = await _run_ffmpeg(input_path, output_path, crf, start_time, clip_duration)
        if not ok:
            return False
        size = os.path.getsize(output_path)
        logger.info("crf=%d -> %d bytes", crf, size)
        if size <= MAX_SIZE_BYTES:
            return True
        logger.warning("too big (%d), retrying", size)

    logger.error("could not compress to %d bytes", MAX_SIZE_BYTES)
    return False
