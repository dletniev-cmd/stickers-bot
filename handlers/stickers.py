import logging
import os
import tempfile

from aiogram import Bot, F, Router
from aiogram.exceptions import TelegramBadRequest
from aiogram.types import BufferedInputFile, InputSticker, Message

from converter import convert_to_sticker
from database import get_active_pack, mark_pack_initialized

logger = logging.getLogger(__name__)
router = Router()

EMOJI = ["🎥"]


# ─── helper: upload + add sticker ────────────────────────────────────────────

async def _upload_and_add(
    bot: Bot,
    user_id: int,
    short_name: str,
    pack_name: str,
    is_initialized: bool,
    webm_data: bytes,
) -> None:
    """
    Если набор ещё не создан — создаём через createNewStickerSet.
    Если уже есть — добавляем через addStickerToSet.
    """
    sticker_file = BufferedInputFile(webm_data, filename="sticker.webm")

    if not is_initialized:
        await bot.create_new_sticker_set(
            user_id=user_id,
            name=short_name,
            title=pack_name,
            stickers=[
                InputSticker(
                    sticker=sticker_file,
                    emoji_list=EMOJI,
                    format="video",
                )
            ],
        )
    else:
        # Сначала загружаем файл, получаем file_id
        uploaded = await bot.upload_sticker_file(
            user_id=user_id,
            sticker=sticker_file,
            sticker_format="video",
        )
        await bot.add_sticker_to_set(
            user_id=user_id,
            name=short_name,
            sticker=InputSticker(
                sticker=uploaded.file_id,
                emoji_list=EMOJI,
                format="video",
            ),
        )


# ─── handler ──────────────────────────────────────────────────────────────────

@router.message(F.video_note | F.video)
async def handle_video(message: Message, bot: Bot) -> None:
    user_id = message.from_user.id

    # Проверяем активный набор
    active = await get_active_pack(user_id)
    if not active:
        await message.reply(
            "сначала выбери или создай набор — отправь /start"
        )
        return

    pack_id, _, pack_name, short_name, is_initialized = active

    # Определяем файл
    if message.video_note:
        tg_file = message.video_note
    else:
        tg_file = message.video

    status = await message.reply("⏳ обрабатываю...")

    with tempfile.TemporaryDirectory() as tmpdir:
        input_path = os.path.join(tmpdir, "input.mp4")
        output_path = os.path.join(tmpdir, "sticker.webm")

        # Скачиваем
        try:
            file_info = await bot.get_file(tg_file.file_id)
            await bot.download_file(file_info.file_path, destination=input_path)
        except Exception as e:
            logger.error("Download error: %s", e)
            await status.edit_text("не удалось скачать файл, попробуй ещё раз")
            return

        # Конвертируем
        ok = await convert_to_sticker(input_path, output_path)
        if not ok:
            await status.edit_text(
                "не удалось конвертировать видео\n"
                "убедись что это обычное видео или кружок"
            )
            return

        # Читаем результат
        with open(output_path, "rb") as f:
            webm_data = f.read()

        # Добавляем в набор
        try:
            await _upload_and_add(
                bot=bot,
                user_id=user_id,
                short_name=short_name,
                pack_name=pack_name,
                is_initialized=bool(is_initialized),
                webm_data=webm_data,
            )
        except TelegramBadRequest as e:
            err = str(e).lower()
            logger.error("Telegram error: %s", e)

            if "stickerset_invalid" in err or "name is already occupied" in err:
                await status.edit_text(
                    "это имя набора уже занято на телеграме\n"
                    "создай новый набор с другой ссылкой — отправь /start"
                )
            elif "video_sticker_too_big" in err:
                await status.edit_text("видео слишком большое после конвертации, попробуй более короткое")
            elif "sticker_video_no_alpha" in err:
                await status.edit_text("не удалось создать прозрачный фон, попробуй другое видео")
            else:
                await status.edit_text(f"ошибка телеграма: {e}")
            return
        except Exception as e:
            logger.error("Unexpected error: %s", e)
            await status.edit_text(f"неожиданная ошибка: {e}")
            return

        # Если набор только что создан — отмечаем в БД
        if not is_initialized:
            await mark_pack_initialized(pack_id)

    # Удаляем статус-сообщение и отправляем готовый стикер
    try:
        await status.delete()
    except Exception:
        pass

    try:
        sticker_set = await bot.get_sticker_set(short_name)
        last_sticker = sticker_set.stickers[-1]
        await message.reply_sticker(last_sticker.file_id)
    except Exception as e:
        logger.error("Error sending sticker back: %s", e)
        await message.reply("стикер добавлен в набор")
