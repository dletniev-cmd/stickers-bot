import asyncio
import logging
import os
import tempfile

import imageio_ffmpeg

logger = logging.getLogger(__name__)

_FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()

MAX_SIZE_BYTES       = 256 * 1024
MAX_STICKER_DURATION = 8.0

# Фото → статичный webp (scale только, без прозрачности)
_VF_PHOTO_WEBP = (
    "scale=512:512:force_original_aspect_ratio=decrease,"
    "pad=512:512:(ow-iw)/2:(oh-ih)/2:color=white"
)


def _vf_video(size: int) -> str:
    """Круглая маска с заданным разрешением."""
    return (
        f"scale={size}:{size}:force_original_aspect_ratio=increase,"
        f"crop={size}:{size},"
        "format=rgba,"
        "geq="
        "r='r(X,Y)':"
        "g='g(X,Y)':"
        "b='b(X,Y)':"
        f"a='255*lt(hypot(X-W/2,Y-H/2),W/2)',"
        "format=yuva420p"
    )


async def convert_photo_to_webp(input_path: str, output_path: str) -> bool:
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
    size: int,
    fps: int,
    start_time: float,
    clip_duration: float,
) -> bool:
    cmd = [_FFMPEG, "-y"]
    if start_time > 0:
        cmd += ["-ss", f"{start_time:.3f}"]
    cmd += [
        "-i", input_path,
        "-vf", _vf_video(size),
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
        logger.error("ffmpeg error (crf=%d, size=%d, fps=%d):\n%s",
                     crf, size, fps, stderr.decode(errors="replace"))
        return False
    return True


# Таблица попыток: (crf, size, fps)
# От лучшего качества к сжатому. Остановимся на первом, что влезет в 256кб.
_ATTEMPTS = [
    (33, 512, 30),
    (40, 512, 30),
    (48, 512, 24),
    (55, 512, 20),
    (48, 384, 30),
    (55, 384, 24),
    (40, 256, 30),
    (50, 256, 30),
    (60, 256, 24),
    (63, 256, 20),
]


async def convert_to_sticker(
    input_path: str,
    output_path: str,
    start_time: float = 0.0,
    clip_duration: float = MAX_STICKER_DURATION,
) -> bool:
    for crf, size, fps in _ATTEMPTS:
        ok = await _run_ffmpeg(input_path, output_path, crf, size, fps, start_time, clip_duration)
        if not ok:
            return False
        file_size = os.path.getsize(output_path)
        logger.info("crf=%d size=%d fps=%d → %d bytes", crf, size, fps, file_size)
        if file_size <= MAX_SIZE_BYTES:
            return True
        logger.warning("too big (%d bytes), next attempt", file_size)

    logger.error("all attempts failed, still > 256kb")
    return False
