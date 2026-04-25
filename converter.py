import asyncio
import logging
import os

import imageio_ffmpeg

logger = logging.getLogger(__name__)

_FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()

MAX_SIZE_BYTES       = 256 * 1024
MAX_STICKER_DURATION = 3.0

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

# Фото → квадрат со скруглёнными углами (радиус 80 px при 512x512 ≈ 15 %)
# Логика: пиксель прозрачен, только если он в угловой зоне (cx<R И cy<R)
# И при этом дальше R от центра ближайшего угла.
_VF_PHOTO = (
    "scale=512:512:force_original_aspect_ratio=increase,"
    "crop=512:512,"
    "format=rgba,"
    "geq="
    "r='r(X,Y)':"
    "g='g(X,Y)':"
    "b='b(X,Y)':"
    "a='255*(1-lt(min(X,W-1-X),80)*lt(min(Y,H-1-Y),80)*gt(hypot(min(X,W-1-X)-80,min(Y,H-1-Y)-80),80))',"
    "format=yuva420p"
)



# Фото → статичный webp: просто скейл, без прозрачности (TG сам обрежет)
_VF_PHOTO_WEBP = (
    "scale=512:512:force_original_aspect_ratio=decrease,"
    "pad=512:512:(ow-iw)/2:(oh-ih)/2:color=black@0"
)


async def convert_photo_to_webp(input_path: str, output_path: str) -> bool:
    """Фото → статичный webp стикер (512x512, прозрачный фон)."""
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
        logger.error("ffmpeg photo→webp error:\n%s", stderr.decode(errors="replace"))
        return False
    size = os.path.getsize(output_path)
    logger.info("photo webp size: %d bytes", size)
    return size <= MAX_SIZE_BYTES

def _scale_vf(base_vf: str, size: int) -> str:
    """Подменяет scale=512:512 на нужный размер."""
    return base_vf.replace("scale=512:512", f"scale={size}:{size}").replace(
        f"crop=512:512", f"crop={size}:{size}"
    )


async def _run_ffmpeg(
    input_path: str,
    output_path: str,
    crf: int,
    is_photo: bool,
    size: int = 512,
    fps: int = 30,
    start_time: float = 0.0,
    clip_duration: float = MAX_STICKER_DURATION,
) -> bool:
    base_vf = _VF_PHOTO if is_photo else _VF_VIDEO
    vf = _scale_vf(base_vf, size)

    cmd = [_FFMPEG, "-y"]

    if is_photo:
        cmd += ["-loop", "1"]
    elif start_time > 0.0:
        cmd += ["-ss", f"{start_time:.3f}"]

    cmd += [
        "-i", input_path,
        "-vf", vf,
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
        logger.error("ffmpeg error (crf=%d, size=%d):\n%s", crf, size, stderr.decode(errors="replace"))
        return False
    return True


# (crf, size, fps) — от лучшего к самому сжатому
_ATTEMPTS = [
    (33, 512, 30),
    (43, 512, 30),
    (55, 512, 24),
    (48, 384, 30),
    (55, 384, 24),
    (43, 256, 30),
    (55, 256, 30),
    (63, 256, 20),
]


async def convert_to_sticker(
    input_path: str,
    output_path: str,
    is_photo: bool = False,
    start_time: float = 0.0,
    clip_duration: float = MAX_STICKER_DURATION,
) -> bool:
    for crf, size, fps in _ATTEMPTS:
        ok = await _run_ffmpeg(
            input_path, output_path, crf, is_photo, size, fps, start_time, clip_duration
        )
        if not ok:
            continue  # ffmpeg error → пробуем следующий вариант
        file_size = os.path.getsize(output_path)
        logger.info("crf=%d size=%d fps=%d -> %d bytes", crf, size, fps, file_size)
        if file_size <= MAX_SIZE_BYTES:
            return True
        logger.warning("too big (%d bytes), next attempt", file_size)

    logger.error("all attempts failed, still > 256kb")
    return False
