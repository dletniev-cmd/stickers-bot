import asyncio
import logging
import os

import imageio_ffmpeg

logger = logging.getLogger(__name__)

_FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()

# Telegram ограничивает видеостикеры до 256 KB
MAX_SIZE_BYTES = 256 * 1024


async def _run_ffmpeg(input_path: str, output_path: str, crf: int, is_photo: bool) -> bool:
    vf = (
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

    cmd = [_FFMPEG, "-y"]
    if is_photo:
        cmd += ["-loop", "1"]
    cmd += [
        "-i", input_path,
        "-vf", vf,
        "-c:v", "libvpx-vp9",
        "-b:v", "0",
        "-crf", str(crf),
        "-auto-alt-ref", "0",
        "-an",
        "-t", "2.9",
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


async def convert_to_sticker(input_path: str, output_path: str, is_photo: bool = False) -> bool:
    for crf in [33, 38, 43, 48, 55, 63]:
        ok = await _run_ffmpeg(input_path, output_path, crf, is_photo)
        if not ok:
            return False
        size = os.path.getsize(output_path)
        logger.info("crf=%d → %d bytes", crf, size)
        if size <= MAX_SIZE_BYTES:
            return True
        logger.warning("too big (%d), retrying", size)

    logger.error("could not compress to %d bytes", MAX_SIZE_BYTES)
    return False
