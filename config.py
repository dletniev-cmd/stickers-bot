import os

BOT_TOKEN: str = os.environ["BOT_TOKEN"]
DATABASE_PATH: str = os.getenv("DATABASE_PATH", "bot.db")
BOT_USERNAME: str = ""  # заполняется при старте
