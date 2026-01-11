import sqlite3
import os
import logging
from contextlib import contextmanager
from typing import List, Optional, Tuple
from .models import PixivTag

logger = logging.getLogger(__name__)


class SQLiteStorage:
    """SQLite 标签存储管理（同步实现）"""

    def __init__(self, db_path: str = "data/pixiv_tags.db"):
        self.db_path = db_path
        self._init_done = False

    @contextmanager
    def _get_connection(self):
        """获取数据库连接（自动关闭）"""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        try:
            yield conn
        finally:
            conn.close()

    def init(self):
        """初始化数据库（只执行一次）"""
        if self._init_done:
            return

        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)

        with self._get_connection() as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS pixiv_tags (
                    name TEXT PRIMARY KEY,
                    official_translation TEXT,
                    chinese_translation TEXT DEFAULT '',
                    english_translation TEXT DEFAULT '',
                    frequency INTEGER DEFAULT 0,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
                )
            """)
            conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_frequency ON pixiv_tags(frequency DESC)"
            )
            conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_translation ON pixiv_tags(official_translation)"
            )
            conn.commit()

        self._init_done = True
        logger.info(f"SQLite 数据库初始化完成: {self.db_path}")

    def upsert_tag(self, tag: PixivTag) -> bool:
        """插入或更新标签（频率累加）"""
        self.init()
        with self._get_connection() as conn:
            conn.execute(
                """
                INSERT INTO pixiv_tags (name, official_translation, chinese_translation, english_translation, frequency)
                VALUES (?, ?, ?, ?, 1)
                ON CONFLICT(name) DO UPDATE SET
                    frequency = frequency + 1,
                    official_translation = COALESCE(?, official_translation),
                    updated_at = CURRENT_TIMESTAMP
            """,
                (
                    tag.name,
                    tag.official_translation,
                    tag.chinese_translation,
                    tag.english_translation,
                    tag.official_translation,
                ),
            )
            conn.commit()
        return True

    def upsert_tags_batch(self, tags: List[PixivTag]) -> int:
        """批量插入或更新（频率累加）"""
        self.init()
        with self._get_connection() as conn:
            for tag in tags:
                conn.execute(
                    """
                    INSERT INTO pixiv_tags (name, official_translation, chinese_translation, english_translation, frequency)
                    VALUES (?, ?, ?, ?, 1)
                    ON CONFLICT(name) DO UPDATE SET
                        frequency = frequency + 1,
                        official_translation = COALESCE(?, official_translation),
                        updated_at = CURRENT_TIMESTAMP
                """,
                    (
                        tag.name,
                        tag.official_translation,
                        tag.chinese_translation,
                        tag.english_translation,
                        tag.official_translation,
                    ),
                )
            conn.commit()
        return len(tags)

    def insert_new_tags_only(self, tags: List[PixivTag]) -> int:
        """只插入不存在的标签（IGNORE），返回实际插入的数量"""
        if not tags:
            return 0

        self.init()
        with self._get_connection() as conn:
            inserted_count = 0
            for tag in tags:
                cursor = conn.execute(
                    """
                    INSERT OR IGNORE INTO pixiv_tags 
                    (name, official_translation, chinese_translation, english_translation, frequency)
                    VALUES (?, ?, ?, ?, ?)
                """,
                    (
                        tag.name,
                        tag.official_translation,
                        tag.chinese_translation,
                        tag.english_translation,
                        tag.frequency,
                    ),
                )
                if cursor.rowcount > 0:
                    inserted_count += 1
            conn.commit()
        return inserted_count

    def apply_frequency_ops(self, ops: List[Tuple[str, int]]) -> int:
        """批量应用频率更新，返回实际更新的行数"""
        if not ops:
            return 0

        self.init()
        with self._get_connection() as conn:
            updated_count = 0
            for name, delta in ops:
                cursor = conn.execute(
                    "UPDATE pixiv_tags SET frequency = frequency + ?, updated_at = CURRENT_TIMESTAMP WHERE name = ?",
                    (delta, name),
                )
                if cursor.rowcount > 0:
                    updated_count += 1
            conn.commit()
        return updated_count

    def get_tag(self, name: str) -> Optional[PixivTag]:
        """查询单个标签"""
        self.init()
        with self._get_connection() as conn:
            cursor = conn.execute("SELECT * FROM pixiv_tags WHERE name = ?", (name,))
            row = cursor.fetchone()
            if row:
                return PixivTag(
                    name=row["name"],
                    official_translation=row["official_translation"],
                    chinese_translation=row["chinese_translation"],
                    english_translation=row["english_translation"],
                    frequency=row["frequency"],
                )
        return None

    def get_all_tags(self) -> List[PixivTag]:
        """获取全部标签"""
        self.init()
        with self._get_connection() as conn:
            cursor = conn.execute("SELECT * FROM pixiv_tags ORDER BY frequency DESC")
            return [
                PixivTag(
                    name=row["name"],
                    official_translation=row["official_translation"],
                    chinese_translation=row["chinese_translation"],
                    english_translation=row["english_translation"],
                    frequency=row["frequency"],
                )
                for row in cursor.fetchall()
            ]

    def count(self) -> int:
        """统计标签数量"""
        self.init()
        with self._get_connection() as conn:
            cursor = conn.execute("SELECT COUNT(*) FROM pixiv_tags")
            result = cursor.fetchone()
            return result[0] if result else 0

    def increment_frequency(self, name: str, delta: int = 1) -> bool:
        """增加标签频率"""
        self.init()
        with self._get_connection() as conn:
            cursor = conn.execute(
                "UPDATE pixiv_tags SET frequency = frequency + ?, updated_at = CURRENT_TIMESTAMP WHERE name = ?",
                (delta, name),
            )
            conn.commit()
            return cursor.rowcount > 0

    def search_by_keyword(self, keyword: str, limit: int = 50) -> List[PixivTag]:
        """模糊搜索标签（新增功能）"""
        self.init()
        with self._get_connection() as conn:
            cursor = conn.execute(
                "SELECT * FROM pixiv_tags WHERE name LIKE ? ORDER BY frequency DESC LIMIT ?",
                (f"%{keyword}%", limit),
            )
            return [
                PixivTag(
                    name=row["name"],
                    official_translation=row["official_translation"],
                    chinese_translation=row["chinese_translation"],
                    english_translation=row["english_translation"],
                    frequency=row["frequency"],
                )
                for row in cursor.fetchall()
            ]

    def get_top_tags(self, limit: int = 100) -> List[PixivTag]:
        """按频率排序获取热门标签（新增功能）"""
        self.init()
        with self._get_connection() as conn:
            cursor = conn.execute(
                "SELECT * FROM pixiv_tags ORDER BY frequency DESC LIMIT ?", (limit,)
            )
            return [
                PixivTag(
                    name=row["name"],
                    official_translation=row["official_translation"],
                    chinese_translation=row["chinese_translation"],
                    english_translation=row["english_translation"],
                    frequency=row["frequency"],
                )
                for row in cursor.fetchall()
            ]
