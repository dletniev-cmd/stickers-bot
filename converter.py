import asyncio
import logging
import os

import imageio_ffmpeg

logger = logging.getLogger(__name__)

# Используем бинарник ffmpeg из imageio-ffmpeg (не зависит от системного PATH)
_FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()

# Telegram ограничивает видеостикеры до 256 KB
MAX_SIZE_BYTES = 256 * 1024


async def _run_ffmpeg(input_path: str, output_path: str, crf: int) -> bool:
    """Запускает ffmpeg с заданным CRF. Возвращает True при успехе."""

    # Фильтр:
    # 1. scale — масштабируем так чтобы меньшая сторона = 512
    # 2. crop — берём центр 512×512
    # 3. format=rgba — полноразрядный альфа-канал
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
        "-crf", str(crf),
        "-auto-alt-ref", "0",   # обязательно для альфа VP9
        "-an",                   # без аудио
        "-t", "2.9",               # строго < 3 сек (лимит Telegram)
        output_path
    ]

    logger.info("Running ffmpeg crf=%d: %s", crf, " ".join(cmd))

    proc = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    stdout, stderr = await proc.communicate()

    if proc.returncode != 0:
        logger.error("ffmpeg error (crf=%d):\n%s", crf, stderr.decode(errors="replace"))
        return False

    return True


async def convert_to_sticker(input_path: str, output_path: str) -> bool:
    """
    Конвертирует видео (кружок или обычное видео) в WebM VP9
    512×512 с круговой маской (прозрачный фон вне круга).
    Максимум 3 секунды, без аудио.

    Автоматически повышает CRF (снижает качество) пока файл
    не войдёт в лимит Telegram — 256 KB.
    """

    # Начинаем с хорошего качества, шагаем по +5 до максимума
    crf_values = [33, 38, 43, 48, 55, 63]

    for crf in crf_values:
        ok = await _run_ffmpeg(input_path, output_path, crf)
        if not ok:
            return False

        size = os.path.getsize(output_path)
        logger.info("crf=%d → %d bytes (limit %d)", crf, size, MAX_SIZE_BYTES)

        if size <= MAX_SIZE_BYTES:
            return True

        logger.warning("File too big (%d bytes), retrying with higher CRF", size)

    # Последняя попытка не уложилась — сообщаем размер для отладки
    size = os.path.getsize(output_path)
    logger.error("Could not compress to %d bytes, final size: %d", MAX_SIZE_BYTES, size)
    return False
