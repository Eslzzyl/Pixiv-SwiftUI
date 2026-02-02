#!/usr/bin/env python3
"""
Pixiv 标签导出脚本

将数据库中的中文翻译导出为 JSON 格式，供主项目使用。

使用方法:
    python export_tags.py

导出格式:
    JSON 对象，键为标签名，值为中文翻译
    {"R-18": "18禁", "オリジナル": "原创", ...}
"""

import json
import logging
import os
import sqlite3
from pathlib import Path
from typing import Dict

from dotenv import load_dotenv

load_dotenv()

log_level = getattr(logging, os.getenv("LOG_LEVEL", "INFO").upper())
log_file = os.getenv("LOG_FILE_PATH", "export_tags.log")

logging.basicConfig(
    level=log_level,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.FileHandler(log_file, encoding="utf-8"),
        logging.StreamHandler(),
    ],
)

logger = logging.getLogger(__name__)


class TagExporter:
    def __init__(self, db_path: str, output_path: str):
        self.db_path = db_path
        self.output_path = output_path

    def get_translated_tags(self) -> Dict[str, str]:
        """从数据库获取所有已翻译的标签"""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        try:
            cursor = conn.execute(
                """
                SELECT name, chinese_translation
                FROM pixiv_tags
                WHERE chinese_translation IS NOT NULL 
                  AND chinese_translation != ''
                ORDER BY frequency DESC
                """
            )
            return {
                row["name"]: row["chinese_translation"] for row in cursor.fetchall()
            }
        finally:
            conn.close()

    def export(self) -> bool:
        """导出标签到 JSON 文件"""
        logger.info("开始导出标签翻译...")

        tags = self.get_translated_tags()
        total_count = len(tags)

        if total_count == 0:
            logger.warning("没有找到已翻译的标签")
            return False

        logger.info(f"找到 {total_count} 个已翻译的标签")

        os.makedirs(os.path.dirname(self.output_path), exist_ok=True)

        with open(self.output_path, "w", encoding="utf-8") as f:
            json.dump(tags, f, ensure_ascii=False, indent=2)

        file_size = os.path.getsize(self.output_path)
        logger.info(f"导出成功: {self.output_path}")
        logger.info(f"文件大小: {file_size:,} 字节")
        logger.info(f"标签数量: {total_count:,}")

        return True


def main():
    db_path = os.getenv("SQLITE_DB_PATH", "data/pixiv_tags.db")
    output_path = "../Resources/tags.json"

    logger.info(f"数据库: {db_path}")
    logger.info(f"输出文件: {output_path}")

    if not os.path.exists(db_path):
        logger.error(f"数据库文件不存在: {db_path}")
        return 1

    try:
        exporter = TagExporter(db_path, output_path)
        success = exporter.export()

        if not success:
            return 1

        return 0

    except Exception as e:
        logger.error(f"导出过程中出错: {e}")
        raise


if __name__ == "__main__":
    import sys

    sys.exit(main())
