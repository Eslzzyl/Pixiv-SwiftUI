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
                    chinese_reviewed INTEGER DEFAULT 0,
                    english_reviewed INTEGER DEFAULT 0,
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
                    chinese_reviewed=bool(
                        row["chinese_reviewed"]
                        if "chinese_reviewed" in row.keys()
                        else 0
                    ),
                    english_reviewed=bool(
                        row["english_reviewed"]
                        if "english_reviewed" in row.keys()
                        else 0
                    ),
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
                    chinese_reviewed=bool(
                        row["chinese_reviewed"]
                        if "chinese_reviewed" in row.keys()
                        else 0
                    ),
                    english_reviewed=bool(
                        row["english_reviewed"]
                        if "english_reviewed" in row.keys()
                        else 0
                    ),
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
                    chinese_reviewed=bool(
                        row["chinese_reviewed"]
                        if "chinese_reviewed" in row.keys()
                        else 0
                    ),
                    english_reviewed=bool(
                        row["english_reviewed"]
                        if "english_reviewed" in row.keys()
                        else 0
                    ),
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
                    chinese_reviewed=bool(
                        row["chinese_reviewed"]
                        if "chinese_reviewed" in row.keys()
                        else 0
                    ),
                    english_reviewed=bool(
                        row["english_reviewed"]
                        if "english_reviewed" in row.keys()
                        else 0
                    ),
                )
                for row in cursor.fetchall()
            ]

    def get_tags_for_review(
        self, language: str = "chinese", limit: int = 100, offset: int = 0
    ) -> List[PixivTag]:
        """获取待审核的标签（按频率排序）"""
        self.init()
        reviewed_column = f"{language}_reviewed"
        with self._get_connection() as conn:
            cursor = conn.execute(
                f"""
                SELECT * FROM pixiv_tags
                WHERE {reviewed_column} = 0
                ORDER BY frequency DESC
                LIMIT ? OFFSET ?
                """,
                (limit, offset),
            )
            return [
                PixivTag(
                    name=row["name"],
                    official_translation=row["official_translation"],
                    chinese_translation=row["chinese_translation"],
                    english_translation=row["english_translation"],
                    frequency=row["frequency"],
                    chinese_reviewed=bool(
                        row["chinese_reviewed"]
                        if "chinese_reviewed" in row.keys()
                        else 0
                    ),
                    english_reviewed=bool(
                        row["english_reviewed"]
                        if "english_reviewed" in row.keys()
                        else 0
                    ),
                )
                for row in cursor.fetchall()
            ]

    def get_tag_by_index(
        self, index: int, language: str = "chinese"
    ) -> Optional[PixivTag]:
        """按索引获取标签（按频率排序）"""
        self.init()
        with self._get_connection() as conn:
            cursor = conn.execute(
                """
                SELECT * FROM pixiv_tags
                ORDER BY frequency DESC
                LIMIT 1 OFFSET ?
                """,
                (index,),
            )
            row = cursor.fetchone()
            if row:
                return PixivTag(
                    name=row["name"],
                    official_translation=row["official_translation"],
                    chinese_translation=row["chinese_translation"],
                    english_translation=row["english_translation"],
                    frequency=row["frequency"],
                    chinese_reviewed=bool(
                        row["chinese_reviewed"]
                        if "chinese_reviewed" in row.keys()
                        else 0
                    ),
                    english_reviewed=bool(
                        row["english_reviewed"]
                        if "english_reviewed" in row.keys()
                        else 0
                    ),
                )
        return None

    def get_next_unreviewed(
        self, current_tag_name: str, language: str = "chinese"
    ) -> Optional[PixivTag]:
        """获取当前标签之后的下一个未审核标签（按频率降序）"""
        self.init()
        reviewed_column = f"{language}_reviewed"
        with self._get_connection() as conn:
            cursor = conn.execute(
                f"""
                SELECT * FROM pixiv_tags
                WHERE frequency < (
                    SELECT frequency FROM pixiv_tags WHERE name = ?
                )
                AND {reviewed_column} = 0
                ORDER BY frequency DESC
                LIMIT 1
                """,
                (current_tag_name,),
            )
            row = cursor.fetchone()
            if row:
                return PixivTag(
                    name=row["name"],
                    official_translation=row["official_translation"],
                    chinese_translation=row["chinese_translation"],
                    english_translation=row["english_translation"],
                    frequency=row["frequency"],
                    chinese_reviewed=bool(
                        row["chinese_reviewed"]
                        if "chinese_reviewed" in row.keys()
                        else 0
                    ),
                    english_reviewed=bool(
                        row["english_reviewed"]
                        if "english_reviewed" in row.keys()
                        else 0
                    ),
                )
        return None

    def get_prev_unreviewed(
        self, current_tag_name: str, language: str = "chinese"
    ) -> Optional[PixivTag]:
        """获取当前标签之前的上一个未审核标签（按频率降序）"""
        self.init()
        reviewed_column = f"{language}_reviewed"
        with self._get_connection() as conn:
            cursor = conn.execute(
                f"""
                SELECT * FROM pixiv_tags
                WHERE frequency > (
                    SELECT frequency FROM pixiv_tags WHERE name = ?
                )
                AND {reviewed_column} = 0
                ORDER BY frequency ASC
                LIMIT 1
                """,
                (current_tag_name,),
            )
            row = cursor.fetchone()
            if row:
                return PixivTag(
                    name=row["name"],
                    official_translation=row["official_translation"],
                    chinese_translation=row["chinese_translation"],
                    english_translation=row["english_translation"],
                    frequency=row["frequency"],
                    chinese_reviewed=bool(
                        row["chinese_reviewed"]
                        if "chinese_reviewed" in row.keys()
                        else 0
                    ),
                    english_reviewed=bool(
                        row["english_reviewed"]
                        if "english_reviewed" in row.keys()
                        else 0
                    ),
                )
        return None

    def get_review_count(self, language: str = "chinese") -> dict:
        """获取审核统计信息"""
        self.init()
        reviewed_column = f"{language}_reviewed"
        with self._get_connection() as conn:
            cursor = conn.execute(
                f"""
                SELECT
                    COUNT(*) as total,
                    SUM(CASE WHEN {reviewed_column} = 1 THEN 1 ELSE 0 END) as reviewed,
                    SUM(CASE WHEN {reviewed_column} = 0 THEN 1 ELSE 0 END) as pending
                FROM pixiv_tags
                """
            )
            row = cursor.fetchone()
            return {
                "total": row[0] or 0,
                "reviewed": row[1] or 0,
                "pending": row[2] or 0,
            }

    def update_translation_and_review(
        self,
        name: str,
        chinese_translation: Optional[str] = None,
        english_translation: Optional[str] = None,
        chinese_reviewed: Optional[bool] = None,
        english_reviewed: Optional[bool] = None,
    ) -> bool:
        """更新翻译和审核状态"""
        self.init()
        with self._get_connection() as conn:
            updates = []
            params = []

            if chinese_translation is not None:
                updates.append("chinese_translation = ?")
                params.append(chinese_translation)

            if english_translation is not None:
                updates.append("english_translation = ?")
                params.append(english_translation)

            if chinese_reviewed is not None:
                updates.append("chinese_reviewed = ?")
                params.append(1 if chinese_reviewed else 0)

            if english_reviewed is not None:
                updates.append("english_reviewed = ?")
                params.append(1 if english_reviewed else 0)

            if not updates:
                return False

            updates.append("updated_at = CURRENT_TIMESTAMP")
            params.append(name)

            query = f"UPDATE pixiv_tags SET {', '.join(updates)} WHERE name = ?"
            cursor = conn.execute(query, params)
            conn.commit()
            return cursor.rowcount > 0
