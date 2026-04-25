import asyncio
import logging
import os
import tempfile
from collections import defaultdict

from aiogram import Bot, F, Router
from aiogram.exceptions import TelegramBadRequest
from aiogram.types import (
    BufferedInputFile,
    InputSticker,
    Message,
)

from converter import convert_to_sticker, convert_photo_to_webp, MAX_STICKER_DURATION
from database import get_active_pack, mark_pack_initialized

logger = logging.getLogger(__name__)
router = Router()

EMOJI = ["🎥"]

_album_buffers: dict[str, list[Message]] = defaultdict(list)
_album_tasks:   dict[str, asyncio.Task]   = {}


def _get_tg_file(message: Message):
    if message.video_note:
        return message.video_note, False
    if message.video:
        return message.video, False
    if message.photo:
        return message.photo[-1], True
    return None, False


def _tg_error_text(e: TelegramBadRequest) -> str:
    err = str(e).lower()
    if "video_sticker_too_big" in err:
        return "файл вышел слишком тяжёлым — попробуй покороче"
    if "sticker_video_no_alpha" in err:
        return "не получилось добавить прозрачность — попробуй другое видео"
    if "stickerset_invalid" in err or "name is already occupied" in err:
        return "имя набора занято — создай новый через /start"
    if "video_too_long" in err or "sticker_video_too_long" in err or "sticker_video_long" in err:
        return "видео слишком длинное — стикер макс 3 секунды"
    if "sticker_file_invalid" in err:
        return "файл не подходит для стикера — попробуй другой"
    return f"ошибка телеграма: {e}"


async def _convert_and_upload(
    bot: Bot,
    user_id: int,
    pack_name: str,
    short_name: str,
    is_initialized: bool,
    tg_file,
    is_photo: bool,
    start_time: float = 0.0,
    clip_duration: float = MAX_STICKER_DURATION,
) -> bool:
    with tempfile.TemporaryDirectory() as tmpdir:
        ext         = "jpg" if is_photo else "mp4"
        input_path  = os.path.join(tmpdir, f"input.{ext}")

        file_info = await bot.get_file(tg_file.file_id)
        await bot.download_file(file_info.file_path, destination=input_path)

        if is_photo:
            output_path = os.path.join(tmpdir, "sticker.webp")
            ok = await convert_photo_to_webp(input_path, output_path)
            sticker_format = "static"
            filename = "sticker.webp"
        else:
            output_path = os.path.join(tmpdir, "sticker.webm")
            ok = await convert_to_sticker(
                input_path, output_path,
                is_photo=False,
                start_time=start_time,
                clip_duration=clip_duration,
            )
            sticker_format = "video"
            filename = "sticker.webm"

        if not ok:
            return False

        with open(output_path, "rb") as f:
            file_data = f.read()

    sticker_file = BufferedInputFile(file_data, filename=filename)

    if not is_initialized:
        await bot.create_new_sticker_set(
            user_id=user_id,
            name=short_name,
            title=pack_name,
            stickers=[InputSticker(sticker=sticker_file, emoji_list=EMOJI, format=sticker_format)],
        )
    else:
        uploaded = await bot.upload_sticker_file(
            user_id=user_id, sticker=sticker_file, sticker_format=sticker_format
        )
        await bot.add_sticker_to_set(
            user_id=user_id,
            name=short_name,
            sticker=InputSticker(sticker=uploaded.file_id, emoji_list=EMOJI, format=sticker_format),
        )

    return True


async def _send_last_sticker(bot: Bot, message: Message, short_name: str, status: Message):
    try:
        sticker_set = await bot.get_sticker_set(short_name)
        last = sticker_set.stickers[-1]
        await status.delete()
        await message.reply_sticker(last.file_id)
    except Exception:
        await status.edit_text("готово ✓")


# ──────────────────────────────── альбом ────────────────────────────────

async def _process_album(media_group_id: str, first_msg: Message, bot: Bot):
    await asyncio.sleep(0.7)

    messages = _album_buffers.pop(media_group_id, [])
    _album_tasks.pop(media_group_id, None)

    if not messages:
        return

    user_id = first_msg.from_user.id
    active  = await get_active_pack(user_id)
    if not active:
        await first_msg.reply("сначала выбери или создай набор — /start")
        return

    pack_id, _, pack_name, short_name, is_initialized = active
    total       = len(messages)
    initialized = bool(is_initialized)
    done        = 0
    failed      = 0

    status = await first_msg.reply(f"делаю стикеры — 0 из {total}…")

    for msg in messages:
        tg_file, is_photo = _get_tg_file(msg)
        if not tg_file:
            failed += 1
            continue

        try:
            ok = await _convert_and_upload(
                bot, user_id, pack_name, short_name, initialized, tg_file, is_photo
            )
            if ok:
                if not initialized:
                    await mark_pack_initialized(pack_id)
                    initialized = True
                done += 1
                suffix = f"  (не удалось: {failed})" if failed else ""
                await status.edit_text(f"делаю стикеры — {done} из {total}{suffix}…")
            else:
                failed += 1

        except TelegramBadRequest as e:
            failed += 1
            logger.error("TG error on album item: %s", e)
        except Exception as e:
            failed += 1
            logger.error("album item error: %s", e)

    if done == 0:
        await status.edit_text(
            f"не получилось создать ни одного стикера 😔\n"
            f"попробуй отправить файлы по одному — так проще найти причину"
        )
        return

    await _send_last_sticker(bot, first_msg, short_name, status)


# ──────────────────────────────── одиночное медиа ────────────────────────────────

@router.message(F.video_note | F.video | F.photo)
async def handle_media(message: Message, bot: Bot) -> None:
    if message.media_group_id:
        mgid = message.media_group_id
        _album_buffers[mgid].append(message)
        if mgid not in _album_tasks:
            _album_tasks[mgid] = asyncio.create_task(
                _process_album(mgid, message, bot)
            )
        return

    user_id = message.from_user.id
    active  = await get_active_pack(user_id)
    if not active:
        await message.reply("сначала выбери или создай набор — /start")
        return

    pack_id, _, pack_name, short_name, is_initialized = active
    tg_file, is_photo = _get_tg_file(message)

    status = await message.reply("делаю стикер…")

    try:
        ok = await _convert_and_upload(
            bot, user_id, pack_name, short_name, bool(is_initialized), tg_file, is_photo
        )
    except TelegramBadRequest as e:
        await status.edit_text(_tg_error_text(e))
        return
    except Exception as e:
        logger.error("error: %s", e)
        await status.edit_text(f"что-то пошло не так: {e}")
        return

    if not ok:
        await status.edit_text(
            "не получилось уложить в 256 кб 😔\n"
            "попробуй видео покороче или с меньшим количеством деталей"
        )
        return

    if not is_initialized:
        await mark_pack_initialized(pack_id)

    await _send_last_sticker(bot, message, short_name, status)
