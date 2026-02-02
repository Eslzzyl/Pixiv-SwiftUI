#!/usr/bin/env python3
"""
Pixiv 标签中文翻译脚本

使用 OpenAI 兼容 API 将 Pixiv 标签翻译成中文。

使用方法:
    python translate_with_llm.py

环境变量配置（.env 文件）:
    OPENAI_BASE_URL="https://api.openai.com/v1"
    OPENAI_API_KEY="your_api_key"
    OPENAI_MODEL_NAME="gpt-4o-mini"
"""

import asyncio
import logging
import os
import signal
import sqlite3
import sys
from typing import List, Optional

from dotenv import load_dotenv
from tqdm import tqdm

from src.llm_api import LLMClient

load_dotenv()

log_level = getattr(logging, os.getenv("LOG_LEVEL", "INFO").upper())
log_file = os.getenv("LOG_FILE_PATH", "translate_llm.log")

logging.basicConfig(
    level=log_level,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.FileHandler(log_file, encoding="utf-8"),
    ],
)

logging.getLogger("httpx").setLevel(logging.WARNING)

logger = logging.getLogger(__name__)


class TagTranslator:
    def __init__(self, db_path: str, llm_client: LLMClient):
        self.db_path = db_path
        self.llm_client = llm_client
        self._init_db()

    def _init_db(self):
        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        conn.close()
        logger.info(f"数据库连接初始化完成: {self.db_path}")

    def get_tags_needing_translation(self, limit: Optional[int] = None) -> List[dict]:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        try:
            query = """
                SELECT name, official_translation, frequency
                FROM pixiv_tags
                WHERE chinese_translation IS NULL OR chinese_translation = ''
                ORDER BY frequency DESC
            """
            if limit:
                query += f" LIMIT {limit}"

            cursor = conn.execute(query)
            return [dict(row) for row in cursor.fetchall()]
        finally:
            conn.close()

    def update_chinese_translation(self, tag_name: str, translation: str) -> bool:
        conn = sqlite3.connect(self.db_path)
        try:
            cursor = conn.execute(
                """
                UPDATE pixiv_tags
                SET chinese_translation = ?, updated_at = CURRENT_TIMESTAMP
                WHERE name = ?
                """,
                (translation, tag_name),
            )
            conn.commit()
            return cursor.rowcount > 0
        finally:
            conn.close()

    def translate_tag(
        self, tag_name: str, official_translation: Optional[str] = None
    ) -> Optional[str]:
        if official_translation:
            prompt = f"""请将以下 Pixiv 标签翻译成中文。如果标签有官方翻译，请参考官方翻译的风格和用词。

标签名称: {tag_name}
官方翻译: {official_translation}

请直接输出中文翻译，不要包含任何解释或额外文字。"""
        else:
            prompt = f"""请将以下 Pixiv 标签翻译成中文。这是 Pixiv 插画网站上的标签，通常与动漫、游戏、艺术相关。

标签名称: {tag_name}

请直接输出中文翻译，不要包含任何解释或额外文字。"""

        try:
            response = self.llm_client.simple_chat(
                text=prompt,
                temperature=0.3,
            )
            translation = response.content.strip()
            return translation
        except Exception:
            return None

    async def translate_tag_async(
        self, tag_name: str, official_translation: Optional[str] = None
    ) -> Optional[str]:
        if official_translation:
            prompt = f"""请将以下 Pixiv 标签翻译成中文。如果标签有官方翻译，请参考官方翻译的风格和用词。

标签名称: {tag_name}
官方翻译: {official_translation}

请直接输出中文翻译，不要包含任何解释或额外文字。"""
        else:
            prompt = f"""请将以下 Pixiv 标签翻译成中文。这是 Pixiv 插画网站上的标签，通常与动漫、游戏、艺术相关。

标签名称: {tag_name}

请直接输出中文翻译，不要包含任何解释或额外文字。"""

        try:
            response = await self.llm_client.simple_chat_async(
                text=prompt,
                temperature=0.3,
            )
            translation = response.content.strip()
            return translation
        except Exception:
            return None

    def translate_all(self):
        tags = self.get_tags_needing_translation()
        total_tags = len(tags)

        if total_tags == 0:
            print("没有需要翻译的标签")
            return

        success_count = 0
        fail_count = 0

        with tqdm(
            tags,
            total=total_tags,
            desc="翻译进度",
            unit="个",
            ncols=100,
            postfix="初始化中...",
        ) as progress_bar:
            for tag in progress_bar:
                tag_name = tag["name"]
                official_translation = tag.get("official_translation")

                progress_bar.set_postfix(
                    {"tag": tag_name, "成功": success_count, "失败": fail_count}
                )

                translation = self.translate_tag(tag_name, official_translation)

                if translation:
                    if self.update_chinese_translation(tag_name, translation):
                        success_count += 1
                    else:
                        fail_count += 1
                else:
                    fail_count += 1

            progress_bar.set_postfix({"成功": success_count, "失败": fail_count})

        print(
            f"\n翻译完成！总计: {total_tags} | 成功: {success_count} | 失败: {fail_count}"
        )

    async def translate_all_async(self, concurrency: int = 20):
        tags = self.get_tags_needing_translation()
        total_tags = len(tags)

        if total_tags == 0:
            print("没有需要翻译的标签")
            return

        success_count = 0
        fail_count = 0
        semaphore = asyncio.Semaphore(concurrency)
        lock = asyncio.Lock()
        stop_event = asyncio.Event()

        async def translate_single(tag: dict):
            nonlocal success_count, fail_count

            if stop_event.is_set():
                return

            async with semaphore:
                if stop_event.is_set():
                    return

                tag_name = tag["name"]
                official_translation = tag.get("official_translation")

                try:
                    translation = await asyncio.wait_for(
                        self.translate_tag_async(tag_name, official_translation),
                        timeout=60.0,
                    )
                except asyncio.TimeoutError:
                    translation = None
                except asyncio.CancelledError:
                    return

                async with lock:
                    if translation:
                        if self.update_chinese_translation(tag_name, translation):
                            success_count += 1
                        else:
                            fail_count += 1
                    else:
                        fail_count += 1
                    progress_bar.update(1)

        def handle_stop(signum, frame):
            stop_event.set()

        original_sigint = signal.signal(signal.SIGINT, handle_stop)
        original_sigterm = signal.signal(signal.SIGTERM, handle_stop)

        try:
            with tqdm(
                total=total_tags,
                desc="翻译进度",
                unit="个",
                ncols=100,
                postfix="初始化中...",
            ) as progress_bar:
                tasks = [translate_single(tag) for tag in tags]
                await asyncio.gather(*tasks)
                progress_bar.set_postfix({"成功": success_count, "失败": fail_count})
        finally:
            signal.signal(signal.SIGINT, original_sigint)
            signal.signal(signal.SIGTERM, original_sigterm)

        print(
            f"\n翻译完成！总计: {total_tags} | 成功: {success_count} | 失败: {fail_count}"
        )


async def main_async():
    db_path = os.getenv("SQLITE_DB_PATH", "data/pixiv_tags.db")
    base_url = os.getenv("OPENAI_BASE_URL")
    api_key = os.getenv("OPENAI_API_KEY")
    model_name = os.getenv("OPENAI_MODEL_NAME", "gpt-4o-mini")

    if not api_key:
        print("未设置 OPENAI_API_KEY 环境变量")
        return 1

    try:
        llm_client = LLMClient(
            api_key=api_key,
            base_url=base_url,
            model=model_name,
            timeout=5.0,
            use_async=True,
        )

        translator = TagTranslator(db_path, llm_client)
        await translator.translate_all_async(concurrency=20)

    except Exception as e:
        print(f"Fatal error: {e}")
        raise
    finally:
        if "llm_client" in locals():
            try:
                await llm_client.close_async()
            except:
                pass

    return 0


def main():
    return asyncio.run(main_async())


if __name__ == "__main__":
    sys.exit(main())
