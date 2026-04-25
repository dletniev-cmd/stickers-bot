import asyncio
import logging
import os

import imageio_ffmpeg

logger = logging.getLogger(__name__)

_FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()

MAX_SIZE_BYTES       = 256 * 1024
MAX_STICKER_DURATION = 3.0

# Видео/кружки → квадрат 512x512, обрезка по центру
_VF_VIDEO = (
    "scale=512:512:force_original_aspect_ratio=increase,"
    "crop=512:512"
)

# Фото → квадрат 512x512, обрезка по центру (TG сам скруглит углы)
_VF_PHOTO_WEBP = (
    "scale=512:512:force_original_aspect_ratio=increase,"
    "crop=512:512"
)


async def convert_photo_to_webp(input_path: str, output_path: str) -> bool:
    """Фото → статичный webp стикер 512x512."""
    cmd = [
        _FFMPEG, "-y",
        "-i", input_path,
        "-vf", _VF_PHOTO_WEBP,
        "-vframes", "1",
        "-quality", "80",
        output_path,
    ]
    proc = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    _, stderr = await proc.communicate()
    if proc.returncode != 0:
        # libwebp может не поддерживать -quality, пробуем -q:v
        cmd2 = [
            _FFMPEG, "-y",
            "-i", input_path,
            "-vf", _VF_PHOTO_WEBP,
            "-vframes", "1",
            "-q:v", "80",
            output_path,
        ]
        proc2 = await asyncio.create_subprocess_exec(
            *cmd2,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        _, stderr2 = await proc2.communicate()
        if proc2.returncode != 0:
            logger.error("ffmpeg photo->webp error:\n%s", stderr2.decode(errors="replace"))
            return False
    size = os.path.getsize(output_path)
    logger.info("photo webp: %d bytes", size)
    return size <= MAX_SIZE_BYTES


async def _run_ffmpeg(
    input_path: str,
    output_path: str,
    crf: int,
    fps: int,
    start_time: float,
    clip_duration: float,
) -> bool:
    cmd = [_FFMPEG, "-y"]
    if start_time > 0:
        cmd += ["-ss", f"{start_time:.3f}"]
    cmd += [
        "-i", input_path,
        "-vf", _VF_VIDEO,
        "-c:v", "libvpx-vp9",
        "-pix_fmt", "yuva420p",
        "-b:v", "0",
        "-crf", str(crf),
        "-r", str(fps),
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
        logger.error("ffmpeg error (crf=%d fps=%d):\n%s",
                     crf, fps, stderr.decode(errors="replace"))
        return False
    return True


# crf + fps — только 512x512 (TG требует строго это разрешение)
_ATTEMPTS = [
    (33, 30),
    (40, 30),
    (48, 24),
    (55, 20),
    (60, 18),
    (63, 15),
]


async def convert_to_sticker(
    input_path: str,
    output_path: str,
    is_photo: bool = False,   # оставлен для совместимости, не используется
    start_time: float = 0.0,
    clip_duration: float = MAX_STICKER_DURATION,
) -> bool:
    for crf, fps in _ATTEMPTS:
        ok = await _run_ffmpeg(input_path, output_path, crf, fps, start_time, clip_duration)
        if not ok:
            continue
        size = os.path.getsize(output_path)
        logger.info("crf=%d fps=%d -> %d bytes", crf, fps, size)
        if size <= MAX_SIZE_BYTES:
            return True
        logger.warning("too big (%d bytes), next attempt", size)

    logger.error("all attempts failed, still > %d bytes", MAX_SIZE_BYTES)
    return False
