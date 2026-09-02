#!/usr/bin/env python3
"""
Pixiv 标签导出脚本

将数据库中的翻译导出为多语言 JSON 格式，供主项目使用。

使用方法:
    python export_tags.py
    python export_tags.py --output /path/to/tags.json

导出格式:
    JSON 对象，每个标签对应一个语言字典
    {"R-18": {"zh": "18禁"}, "オリジナル": {"zh": "原创"}, ...}
"""

import json
import logging
import os
import sqlite3
from argparse import ArgumentParser
from datetime import datetime, timezone
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
    LANGUAGE_COLUMNS = {
        "zh": ("chinese_translation", "chinese_reviewed"),
        "en": ("english_translation", "english_reviewed"),
    }

    def __init__(self, db_path: str, output_path: str | Path):
        self.db_path = db_path
        self.output_path = output_path

    def get_translated_tags(self) -> Dict[str, Dict[str, str]]:
        """从数据库获取所有已审核的翻译标签，按语言组织"""
        conn = None
        try:
            conn = sqlite3.connect(self.db_path)
            conn.row_factory = sqlite3.Row

            # 收集每种语言的翻译
            lang_translations: Dict[str, Dict[str, str]] = {}
            for lang_code, (trans_col, review_col) in self.LANGUAGE_COLUMNS.items():
                cursor = conn.execute(
                    f"""
                    SELECT name, {trans_col} AS translation
                    FROM pixiv_tags
                    WHERE {trans_col} IS NOT NULL
                      AND {trans_col} != ''
                      AND {review_col} = 1
                      AND name NOT GLOB '*[0-9]users入り'
                    ORDER BY frequency DESC
                    """
                )
                rows = cursor.fetchall()
                if rows:
                    lang_translations[lang_code] = {
                        row["name"]: row["translation"] for row in rows
                    }

            # 合并为嵌套结构
            all_tag_names = set()
            for trans_dict in lang_translations.values():
                all_tag_names.update(trans_dict.keys())

            result: Dict[str, Dict[str, str]] = {}
            for name in sorted(all_tag_names):
                lang_dict: Dict[str, str] = {}
                for lang_code, trans_dict in lang_translations.items():
                    if name in trans_dict:
                        lang_dict[lang_code] = trans_dict[name]
                if lang_dict:
                    result[name] = lang_dict

            return result
        except Exception as e:
            logger.error(f"从数据库导出标签失败: {e}")
            return {}
        finally:
            if conn:
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

        timestamp = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace(
            "+00:00", "Z"
        )

        export_data = {"timestamp": timestamp, "tags": tags}

        output_path = Path(self.output_path)
        output_path.parent.mkdir(parents=True, exist_ok=True)

        with output_path.open("w", encoding="utf-8") as f:
            json.dump(export_data, f, ensure_ascii=False, indent=2)
            f.write("\n")

        file_size = output_path.stat().st_size
        logger.info(f"导出成功: {output_path}")
        logger.info(f"时间戳: {timestamp}")
        logger.info(f"文件大小: {file_size:,} 字节")
        logger.info(f"标签数量: {total_count:,}")

        return True


def parse_args():
    parser = ArgumentParser(description="导出已审核的 Pixiv 标签翻译")
    parser.add_argument(
        "--output",
        type=Path,
        help="输出 JSON 文件路径，默认为主项目 Resources/tags.json",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    db_path = os.getenv("SQLITE_DB_PATH", "data/pixiv_tags.db")
    project_root = Path(__file__).resolve().parent.parent
    output_path = args.output or project_root / "Resources" / "tags.json"
    if not output_path.is_absolute():
        output_path = Path.cwd() / output_path

    logger.info(f"数据库: {db_path}")
    logger.info(f"输出文件: {output_path}")

    if not os.path.exists(db_path):
        logger.warning(f"数据库文件不存在: {db_path}，准备生成空模版...")

        # 如果目标文件也不存在，则生成一个空的模版格式
        if not output_path.exists():
            timestamp = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace(
                "+00:00", "Z"
            )
            export_data = {"timestamp": timestamp, "tags": {}}

            output_path.parent.mkdir(parents=True, exist_ok=True)
            with output_path.open("w", encoding="utf-8") as f:
                json.dump(export_data, f, ensure_ascii=False, indent=2)
                f.write("\n")
            logger.info(f"已生成空模版文件: {output_path}")
            return 0
        else:
            logger.error(f"数据库不存在且目标文件已存在，跳过生成: {output_path}")
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
