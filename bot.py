import asyncio
import logging

from aiogram import Bot, Dispatcher
from aiogram.fsm.storage.memory import MemoryStorage

import config
from database import init_db
from handlers.start import router as start_router
from handlers.stickers import router as sticker_router

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)


async def main() -> None:
    if not config.BOT_TOKEN:
        raise ValueError("BOT_TOKEN не задан — добавь его в .env или переменные окружения")

    bot = Bot(token=config.BOT_TOKEN)
    dp = Dispatcher(storage=MemoryStorage())

    # Получаем username бота один раз при старте
    bot_info = await bot.get_me()
    config.BOT_USERNAME = bot_info.username
    logger.info("Bot started: @%s", config.BOT_USERNAME)

    # Инициализируем БД
    await init_db()

    # Подключаем роутеры
    dp.include_router(start_router)
    dp.include_router(sticker_router)

    try:
        await dp.start_polling(bot, allowed_updates=["message", "callback_query"])
    finally:
        await bot.session.close()


if __name__ == "__main__":
    asyncio.run(main())
