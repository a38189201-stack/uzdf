import sys
import asyncio
from pathlib import Path

# Add root folder to sys.path to ensure absolute imports work correctly
root_dir = Path(__file__).resolve().parent.parent
if str(root_dir) not in sys.path:
    sys.path.insert(0, str(root_dir))

from aiogram import Bot, Dispatcher

# Support running directly inside the telegram_bot folder (e.g. on Railway root directory configuration)
try:
    from telegram_bot import config, database, logger
    from telegram_bot.handlers import start, support
except ModuleNotFoundError:
    import types
    import config
    import database
    import logger
    from handlers import start as handlers_start, support as handlers_support
    
    telegram_bot = types.ModuleType('telegram_bot')
    telegram_bot.config = config
    telegram_bot.database = database
    telegram_bot.logger = logger
    
    handlers = types.ModuleType('telegram_bot.handlers')
    handlers.start = handlers_start
    handlers.support = handlers_support
    
    sys.modules['telegram_bot'] = telegram_bot
    sys.modules['telegram_bot.config'] = config
    sys.modules['telegram_bot.database'] = database
    sys.modules['telegram_bot.logger'] = logger
    sys.modules['telegram_bot.handlers'] = handlers
    sys.modules['telegram_bot.handlers.start'] = handlers_start
    sys.modules['telegram_bot.handlers.support'] = handlers_support

    from telegram_bot import config, database, logger
    from telegram_bot.handlers import start, support

# Set up logging to both console and DB
log = logger.setup_logger()

async def main():
    if not config.TELEGRAM_BOT_TOKEN:
        log.error("TELEGRAM_BOT_TOKEN is not set in environment variables! Bot cannot start.")
        return
        
    log.info("Initializing Telegram Support Bot...")
    
    # Initialize DB Pool
    try:
        await database.init_db()
        log.info("Database connection pool initialized successfully.")
    except Exception as e:
        log.critical(f"Failed to connect to the database: {e}")
        return

    bot = Bot(token=config.TELEGRAM_BOT_TOKEN)
    dp = Dispatcher()

    # Include routers (start should precede support)
    dp.include_router(start.router)
    dp.include_router(support.router)

    log.info("Bot handlers registered successfully. Starting long polling...")

    try:
        await dp.start_polling(bot)
    except Exception as e:
        log.critical(f"Critical error during bot polling: {e}")
    finally:
        log.info("Shutting down bot session and closing database connection pool...")
        await bot.session.close()
        await database.close_db()
        log.info("Telegram Support Bot successfully stopped.")

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
