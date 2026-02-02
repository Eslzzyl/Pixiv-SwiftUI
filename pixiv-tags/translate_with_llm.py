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

import logging
import os
import signal
import sqlite3
import sys
from pathlib import Path
from typing import List, Optional

from dotenv import load_dotenv

from src.llm_api import LLMClient

load_dotenv()

log_level = getattr(logging, os.getenv("LOG_LEVEL", "INFO").upper())
log_file = os.getenv("LOG_FILE_PATH", "translate_llm.log")

logging.basicConfig(
    level=log_level,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.FileHandler(log_file, encoding="utf-8"),
        logging.StreamHandler(sys.stdout),
    ],
)

logger = logging.getLogger(__name__)

should_stop = False


def signal_handler(signum, frame):
    global should_stop
    should_stop = True
    logger.info("\n收到退出信号，正在优雅退出...")


def get_should_stop():
    return should_stop


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
        except Exception as e:
            logger.error(f"翻译标签 '{tag_name}' 时出错: {e}")
            return None

    def translate_all(self):
        tags = self.get_tags_needing_translation()
        total_tags = len(tags)

        if total_tags == 0:
            logger.info("没有需要翻译的标签")
            return

        logger.info(f"开始翻译 {total_tags} 个标签")
        logger.info(f"按频率降序翻译，先翻译热门标签")

        success_count = 0
        fail_count = 0

        for idx, tag in enumerate(tags, 1):
            if get_should_stop():
                logger.info("收到停止信号，停止翻译")
                break

            tag_name = tag["name"]
            official_translation = tag.get("official_translation")
            frequency = tag["frequency"]

            logger.info(f"[{idx}/{total_tags}] 翻译中: {tag_name} (频率: {frequency})")

            translation = self.translate_tag(tag_name, official_translation)

            if translation:
                if self.update_chinese_translation(tag_name, translation):
                    success_count += 1
                    logger.info(f"  ✅ 翻译成功: {translation}")
                else:
                    fail_count += 1
                    logger.warning(f"  ⚠️ 更新数据库失败")
            else:
                fail_count += 1
                logger.error(f"  ❌ 翻译失败")

            if idx % 10 == 0:
                logger.info(
                    f"进度: {idx}/{total_tags} ({idx / total_tags * 100:.1f}%) | 成功: {success_count} | 失败: {fail_count}"
                )

        logger.info(
            f"翻译完成！总计: {idx} | 成功: {success_count} | 失败: {fail_count}"
        )


def main():
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    db_path = os.getenv("SQLITE_DB_PATH", "data/pixiv_tags.db")
    base_url = os.getenv("OPENAI_BASE_URL")
    api_key = os.getenv("OPENAI_API_KEY")
    model_name = os.getenv("OPENAI_MODEL_NAME", "gpt-4o-mini")

    if not api_key:
        logger.error("未设置 OPENAI_API_KEY 环境变量")
        return 1

    logger.info("🚀 启动 Pixiv 标签翻译器")
    logger.info(f"数据库: {db_path}")
    logger.info(f"API: {base_url}")
    logger.info(f"模型: {model_name}")
    logger.info("按 Ctrl+C 可以安全退出程序")

    try:
        llm_client = LLMClient(
            api_key=api_key,
            base_url=base_url,
            model=model_name,
            timeout=5.0,
        )

        translator = TagTranslator(db_path, llm_client)
        translator.translate_all()

    except Exception as e:
        logger.error(f"Fatal error: {e}")
        raise
    finally:
        if "llm_client" in locals():
            try:
                llm_client.client.close()
            except:
                pass
        logger.info("翻译程序结束")

    return 0


if __name__ == "__main__":
    sys.exit(main())
