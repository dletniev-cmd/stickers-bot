import re
import logging

from aiogram import Router, F
from aiogram.filters import Command
from aiogram.fsm.context import FSMContext
from aiogram.types import (
    CallbackQuery,
    InlineKeyboardMarkup,
    InlineKeyboardButton,
    Message,
)
from aiogram.utils.keyboard import InlineKeyboardBuilder

import config
from database import (
    create_pack,
    get_active_pack,
    get_user_packs,
    set_active_pack,
    short_name_exists,
)
from states import PackCreation

logger = logging.getLogger(__name__)
router = Router()


# ─── helpers ──────────────────────────────────────────────────────────────────

def build_packs_keyboard(packs: list) -> InlineKeyboardMarkup:
    builder = InlineKeyboardBuilder()
    for pack in packs:
        pid, name, short_name, _ = pack
        builder.button(
            text=name,
            callback_data=f"select_pack:{pid}",
        )
    builder.button(text="＋ создать набор", callback_data="create_pack")
    builder.adjust(1)
    return builder.as_markup()


def packs_text(packs: list) -> str:
    if packs:
        return "приветики, вот твои наборы:"
    return "приветики, у тебя пока нет наборов"


# ─── /start ───────────────────────────────────────────────────────────────────

@router.message(Command("start"))
async def cmd_start(message: Message, state: FSMContext) -> None:
    await state.clear()
    packs = await get_user_packs(message.from_user.id)
    await message.answer(
        packs_text(packs),
        reply_markup=build_packs_keyboard(packs),
    )


# ─── выбор набора ─────────────────────────────────────────────────────────────

@router.callback_query(F.data.startswith("select_pack:"))
async def cb_select_pack(callback: CallbackQuery, state: FSMContext) -> None:
    await state.clear()
    pack_id = int(callback.data.split(":")[1])
    await set_active_pack(callback.from_user.id, pack_id)

    packs = await get_user_packs(callback.from_user.id)
    pack = next((p for p in packs if p[0] == pack_id), None)
    if not pack:
        await callback.answer("набор не найден", show_alert=True)
        return

    _, name, short_name, _ = pack
    link = f"t.me/addstickers/{short_name}"

    await callback.message.edit_text(
        f"активный набор: {name}\n"
        f"ссылка: {link}\n\n"
        "просто кидай кружки или видео — буду добавлять в этот набор",
        reply_markup=build_packs_keyboard(packs),
    )
    await callback.answer()


# ─── создание набора — кнопка ─────────────────────────────────────────────────

@router.callback_query(F.data == "create_pack")
async def cb_create_pack(callback: CallbackQuery, state: FSMContext) -> None:
    await state.set_state(PackCreation.waiting_name)
    await callback.message.edit_text("введи название набора:")
    await callback.answer()


# ─── создание набора — название ───────────────────────────────────────────────

@router.message(PackCreation.waiting_name)
async def process_pack_name(message: Message, state: FSMContext) -> None:
    name = (message.text or "").strip()

    if not name or len(name) > 64:
        await message.answer("название должно быть от 1 до 64 символов, попробуй ещё раз:")
        return

    await state.update_data(pack_name=name)
    await state.set_state(PackCreation.waiting_short_name)

    bot_name = config.BOT_USERNAME
    await message.answer(
        f"теперь придумай короткую ссылку для набора\n"
        f"только латинские буквы, цифры и подчёркивания\n\n"
        f"итоговая ссылка будет выглядеть так:\n"
        f"t.me/addstickers/твоя_ссылка_by_{bot_name}"
    )


# ─── создание набора — короткое имя ──────────────────────────────────────────

@router.message(PackCreation.waiting_short_name)
async def process_pack_short_name(message: Message, state: FSMContext) -> None:
    raw = (message.text or "").strip().lower()

    if not re.match(r"^[a-z0-9_]{1,64}$", raw):
        await message.answer(
            "ссылка может содержать только латинские буквы, цифры и подчёркивания\n"
            "попробуй ещё раз:"
        )
        return

    bot_name = config.BOT_USERNAME
    full_short_name = f"{raw}_by_{bot_name}"

    if await short_name_exists(full_short_name):
        await message.answer("такая ссылка уже занята у тебя — придумай другую:")
        return

    data = await state.get_data()
    pack_name = data["pack_name"]

    pack_id = await create_pack(message.from_user.id, pack_name, full_short_name)
    await set_active_pack(message.from_user.id, pack_id)
    await state.clear()

    link = f"t.me/addstickers/{full_short_name}"
    await message.answer(
        f"набор «{pack_name}» создан\n"
        f"ссылка: {link}\n\n"
        "просто кидай кружки или видео — буду добавлять их сюда и каждый раз скидывать готовый стикер"
    )
