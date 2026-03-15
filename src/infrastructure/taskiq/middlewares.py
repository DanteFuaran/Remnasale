import hashlib
import time
import traceback
from typing import Any

from aiogram.utils.formatting import Text
from loguru import logger
from redis.exceptions import ResponseError
from taskiq import TaskiqMessage, TaskiqResult
from taskiq.abc.middleware import TaskiqMiddleware

from src.core.utils.message_payload import MessagePayload

# Cooldown для дедупликации однотипных ошибок (секунды)
ERROR_DEDUP_COOLDOWN = 300  # 5 минут


class RetryOnNOGROUPMiddleware(TaskiqMiddleware):
    """Middleware to retry on NOGROUP error and initialize consumer group."""
    
    async def on_error(
        self,
        message: TaskiqMessage,
        result: TaskiqResult[Any],
        exception: BaseException,
    ) -> None:
        if isinstance(exception, ResponseError) and "NOGROUP" in str(exception):
            logger.warning("NOGROUP error detected, attempting to initialize consumer group")
            pass
        else:
            await ErrorMiddleware().on_error(message, result, exception)


class ErrorMiddleware(TaskiqMiddleware):
    # Хранилище последних отправленных ошибок: {error_key: timestamp}
    _recent_errors: dict[str, float] = {}

    async def on_error(
        self,
        message: TaskiqMessage,
        result: TaskiqResult[Any],
        exception: BaseException,
    ) -> None:
        # Не отправляем уведомление об ошибке самой задачи уведомления (антирекурсия)
        if "send_error_notification_task" in message.task_name:
            logger.warning(f"Error notification task failed (suppressed): {exception}")
            return

        logger.error(f"Task '{message.task_name}' error: {exception}")

        # Дедупликация: ключ = тип ошибки + имя задачи
        error_key = hashlib.md5(
            f"{message.task_name}:{type(exception).__name__}".encode()
        ).hexdigest()

        now = time.monotonic()
        last_sent = self._recent_errors.get(error_key, 0)
        if now - last_sent < ERROR_DEDUP_COOLDOWN:
            logger.debug(
                f"Suppressed duplicate error notification for '{message.task_name}' "
                f"({type(exception).__name__}), cooldown {ERROR_DEDUP_COOLDOWN}s"
            )
            return

        self._recent_errors[error_key] = now

        # Очистка старых записей (>1 час)
        self._recent_errors = {
            k: v for k, v in self._recent_errors.items() if now - v < 3600
        }

        from src.infrastructure.taskiq.tasks.notifications import (  # noqa: PLC0415
            send_error_notification_task,
        )

        traceback_str = "".join(
            traceback.format_exception(type(exception), exception, exception.__traceback__)
        )
        error_type_name = type(exception).__name__
        error_message = Text(str(exception)[:512])

        await send_error_notification_task.kiq(
            error_id=message.task_id,
            traceback_str=traceback_str,
            payload=MessagePayload.not_deleted(
                i18n_key="ntf-event-error",
                i18n_kwargs={
                    "user": False,
                    "error": f"{error_type_name}: {error_message.as_html()}",
                },
            ),
        )
