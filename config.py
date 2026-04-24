import os

# Токен читается из переменной окружения BOT_TOKEN.
# Никогда не вписывай токен прямо в код — только через env.
BOT_TOKEN: str = os.environ["BOT_TOKEN"]

DATABASE_PATH: str = "bot.db"
BOT_USERNAME: str = ""  # заполняется при старте
