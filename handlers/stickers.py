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


async def _upload_and_add(
    bot: Bot,
    user_id: int,
    short_name: str,
    pack_name: str,
    is_initialized: bool,
    webm_data: bytes,
) -> None:
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


@router.message(F.video_note | F.video)
async def handle_video(message: Message, bot: Bot) -> None:
    user_id = message.from_user.id

    try:
        active = await get_active_pack(user_id)
        if not active:
            await message.reply("сначала выбери или создай набор — отправь /start")
            return

        pack_id, _, pack_name, short_name, is_initialized = active

        if message.video_note:
            tg_file = message.video_note
        else:
            tg_file = message.video

        status = await message.reply("⏳ обрабатываю...")

        with tempfile.TemporaryDirectory() as tmpdir:
            input_path = os.path.join(tmpdir, "input.mp4")
            output_path = os.path.join(tmpdir, "sticker.webm")

            # Скачиваем файл
            try:
                file_info = await bot.get_file(tg_file.file_id)
                await bot.download_file(file_info.file_path, destination=input_path)
            except Exception as e:
                logger.error("Download error: %s", e)
                await status.edit_text(f"не удалось скачать файл: {e}")
                return

            # Конвертируем через ffmpeg
            try:
                ok = await convert_to_sticker(input_path, output_path)
            except Exception as e:
                logger.error("Converter exception: %s", e)
                await status.edit_text(f"ошибка конвертации: {e}")
                return

            if not ok:
                await status.edit_text(
                    "ffmpeg не смог конвертировать видео\n"
                    "убедись что на сервере установлен ffmpeg"
                )
                return

            if not os.path.exists(output_path):
                await status.edit_text("файл после конвертации не найден — что-то пошло не так")
                return

            file_size = os.path.getsize(output_path)
            logger.info("Converted sticker size: %d bytes", file_size)

            with open(output_path, "rb") as f:
                webm_data = f.read()

        # Загружаем в телеграм
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
            logger.error("Telegram API error: %s", e)

            if "stickerset_invalid" in err or "name is already occupied" in err:
                await status.edit_text(
                    "имя набора уже занято на телеграме\n"
                    "создай новый набор с другой ссылкой — отправь /start"
                )
            elif "video_sticker_too_big" in err:
                await status.edit_text("видео слишком большое, попробуй покороче")
            elif "sticker_video_no_alpha" in err:
                await status.edit_text("не удалось добавить альфа-канал, попробуй другое видео")
            elif "peer_id_invalid" in err or "bot_admin" in err:
                await status.edit_text(
                    f"ошибка прав: {e}\n"
                    "убедись что бот создан через @BotFather и у него есть права на создание стикеров"
                )
            else:
                await status.edit_text(f"ошибка телеграма: {e}")
            return
        except Exception as e:
            logger.error("Unexpected upload error: %s", e)
            await status.edit_text(f"неожиданная ошибка при загрузке: {e}")
            return

        # Первый стикер — отмечаем набор как созданный
        if not is_initialized:
            await mark_pack_initialized(pack_id)

        # Удаляем статус и присылаем стикер
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
            await message.reply("стикер добавлен в набор ✓")

    except Exception as e:
        logger.exception("Unhandled error in handle_video: %s", e)
        try:
            await message.reply(f"что-то пошло не так: {e}")
        except Exception:
            pass
