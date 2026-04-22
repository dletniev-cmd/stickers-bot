import asyncio
import logging
import os

import imageio_ffmpeg

logger = logging.getLogger(__name__)

# Используем бинарник ffmpeg из imageio-ffmpeg (не зависит от системного PATH)
_FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()


async def convert_to_sticker(input_path: str, output_path: str) -> bool:
    """
    Конвертирует видео (кружок или обычное видео) в WebM VP9
    512×512 с круговой маской (прозрачный фон вне круга).
    Максимум 3 секунды, без аудио, высокое качество.
    """

    # Фильтр:
    # 1. scale — масштабируем так чтобы меньшая сторона = 512
    # 2. crop — берём центр 512×512
    # 3. format=rgba — полноразрядный альфа-канал (проще чем yuva420p)
    # 4. geq — круговая маска: за пределами окружности a=0 (прозрачно)
    # 5. format=yuva420p — финальная конвертация для VP9-энкодера
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

    cmd = [
        _FFMPEG, "-y",
        "-i", input_path,
        "-vf", vf,
        "-c:v", "libvpx-vp9",
        "-b:v", "0",
        "-crf", "18",           # высокое качество
        "-auto-alt-ref", "0",   # обязательно для альфа VP9
        "-an",                   # без аудио
        "-t", "3",              # макс 3 секунды
        output_path
    ]

    logger.info("Running ffmpeg: %s", " ".join(cmd))

    proc = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE
    )
    stdout, stderr = await proc.communicate()

    if proc.returncode != 0:
        logger.error("ffmpeg error:\n%s", stderr.decode(errors="replace"))
        return False

    size = os.path.getsize(output_path)
    logger.info("Output file size: %d bytes", size)
    return True
