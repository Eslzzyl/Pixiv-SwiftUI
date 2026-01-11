import json
import os
import logging
from typing import List, Tuple
from .models import PixivTag
from .sqlite_storage import SQLiteStorage


logger = logging.getLogger(__name__)


class _JsonTagStorage:
    """原有的 JSON 存储实现（内部使用）"""

    def __init__(self, file_path: str):
        self.file_path = file_path
        self.tags: List[PixivTag] = []
        self.tag_names: set = set()

    def load_to_memory(self) -> int:
        """将数据文件加载到内存"""
        if not os.path.exists(self.file_path):
            logger.info(f"Tag file {self.file_path} does not exist, starting fresh")
            return 0

        try:
            with open(self.file_path, "r", encoding="utf-8") as f:
                data = json.load(f)
                self.tags = []
                self.tag_names = set()

                for tag_data in data.get("tags", []):
                    tag = PixivTag(
                        name=tag_data["name"],
                        official_translation=tag_data.get("official_translation"),
                        chinese_translation=tag_data.get("chinese_translation", ""),
                        english_translation=tag_data.get("english_translation", ""),
                        frequency=tag_data.get("frequency", 0),
                    )
                    self.tags.append(tag)
                    self.tag_names.add(tag.name)

                logger.info(f"Loaded {len(self.tags)} existing tags into memory")
                return len(self.tags)

        except Exception as e:
            logger.error(f"Failed to load tags from {self.file_path}: {e}")
            self.tags = []
            self.tag_names = set()
            return 0

    def add_tags_to_memory(self, new_tags: List[PixivTag]) -> int:
        """将新标签添加到内存中，更新已存在标签的频率"""
        added_count = 0

        for tag in new_tags:
            if tag.name not in self.tag_names:
                # 新标签，添加到内存
                self.tags.append(tag)
                self.tag_names.add(tag.name)
                added_count += 1
            else:
                # 已存在的标签，更新频率
                for existing_tag in self.tags:
                    if existing_tag.name == tag.name:
                        existing_tag.frequency += tag.frequency
                        break

        logger.debug(
            f"Added {added_count} new tags and updated frequencies. Total: {len(self.tags)}"
        )
        return added_count

    def save_from_memory(self) -> bool:
        """从内存保存标签到文件"""
        try:
            data = {"tags": [tag.to_dict() for tag in self.tags]}

            # 确保目录存在
            os.makedirs(os.path.dirname(self.file_path), exist_ok=True)

            # 备份现有文件
            if os.path.exists(self.file_path):
                backup_path = f"{self.file_path}.backup"
                os.rename(self.file_path, backup_path)
                logger.debug(f"Created backup at {backup_path}")

            with open(self.file_path, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=2)

            logger.info(f"Saved {len(self.tags)} tags to {self.file_path}")
            return True

        except Exception as e:
            logger.error(f"Failed to save tags to {self.file_path}: {e}")
            return False


class TagStorage:
    """标签数据存储管理"""

    def __init__(self, file_path: str = None):
        self.mode = os.getenv("PERSISTENT_MODE", "json")  # json | sqlite
        self.json_path = file_path or os.getenv("TAGS_FILE_PATH", "data/tags.json")
        self.sqlite_path = os.getenv("SQLITE_DB_PATH", "data/pixiv_tags.db")

        if self.mode == "sqlite":
            self.sqlite = SQLiteStorage(self.sqlite_path)
            self.tags = []  # 内存缓存
            self.tag_names = set()
            # 增量更新相关
            self.pending_new_tags: List[PixivTag] = []  # 待同步的新标签
            self.pending_freq_ops: List[
                Tuple[str, int]
            ] = []  # 待同步的频率操作 [(name, delta), ...]
            self.sync_interval: int = int(
                os.getenv("SAVE_INTERVAL", "20")
            )  # 每 N 个插画同步一次
            self.illusts_since_sync: int = 0  # 自上次同步后的插画数
            logger.info(
                f"使用 SQLite 模式，数据库路径: {self.sqlite_path}, 同步间隔: {self.sync_interval} 个插画"
            )
        else:
            self._json_storage = _JsonTagStorage(self.json_path)
            self.tags = []
            self.tag_names = set()
            logger.info(f"使用 JSON 模式，文件路径: {self.json_path}")

    def load_to_memory(self) -> int:
        """将数据加载到内存"""
        if self.mode == "sqlite":
            try:
                # 同步加载
                self.tags = self.sqlite.get_all_tags()
                self.tag_names = {tag.name for tag in self.tags}

                logger.info(f"从 SQLite 加载了 {len(self.tags)} 个标签到内存")
                return len(self.tags)
            except Exception as e:
                logger.error(f"从 SQLite 加载标签失败: {e}")
                self.tags = []
                self.tag_names = set()
                return 0
        else:
            return self._json_storage.load_to_memory()

    def add_tags_to_memory(self, new_tags: List[PixivTag]) -> int:
        """将新标签添加到内存中，更新已存在标签的频率（仅内存操作）"""
        if self.mode == "sqlite":
            added_count = 0

            for tag in new_tags:
                if tag.name not in self.tag_names:
                    # 新标签，添加到内存
                    self.tags.append(tag)
                    self.tag_names.add(tag.name)
                    added_count += 1
                    # 累积到待同步列表
                    self.pending_new_tags.append(tag)
                else:
                    # 已存在的标签，更新内存中的频率
                    for existing_tag in self.tags:
                        if existing_tag.name == tag.name:
                            existing_tag.frequency += tag.frequency
                            break

            logger.debug(
                f"Added {added_count} new tags and updated frequencies. Total: {len(self.tags)}"
            )
            return added_count
        else:
            return self._json_storage.add_tags_to_memory(new_tags)

    def save_from_memory(self) -> bool:
        """从内存保存标签（SQLite 模式下为强制同步）"""
        if self.mode == "sqlite":
            try:
                result = self.force_sync()
                if result:
                    logger.info(f"同步了 {len(self.tags)} 个标签到 SQLite")
                return result
            except Exception as e:
                logger.error(f"保存到 SQLite 失败: {e}")
                return False
        else:
            return self._json_storage.save_from_memory()

    def get_memory_count(self) -> int:
        """获取内存中的标签数量"""
        return len(self.tags)

    def get_memory_tags(self) -> List[PixivTag]:
        """获取内存中的所有标签"""
        return self.tags.copy()

    def is_tag_in_memory(self, tag_name: str) -> bool:
        """检查标签是否已在内存中"""
        return tag_name in self.tag_names

    def increment_tag_frequency(self, tag_name: str, increment: int = 1) -> bool:
        """增加标签频率（仅内存操作）"""
        # 更新内存
        for tag in self.tags:
            if tag.name == tag_name:
                tag.frequency += increment
                # 累积到待同步列表（SQLite 模式）
                if self.mode == "sqlite":
                    self.pending_freq_ops.append((tag_name, increment))
                return True
        return False

    def on_illust_processed(self):
        """当处理完一个插画后调用，用于检查自动同步（基于插画计数）"""
        if self.mode != "sqlite":
            return

        self.illusts_since_sync += 1
        self._try_auto_sync()

    def _try_auto_sync(self):
        """检查是否需要自动同步到数据库（基于插画计数）"""
        if self.mode != "sqlite":
            return

        if self.illusts_since_sync >= self.sync_interval:
            self.sync_to_database()

    def sync_to_database(self) -> bool:
        """将累积的更新同步到数据库（增量同步）"""
        if self.mode != "sqlite":
            return False

        if not self.pending_new_tags and not self.pending_freq_ops:
            self.illusts_since_sync = 0
            return True

        try:
            # 同步新标签
            if self.pending_new_tags:
                inserted = self.sqlite.insert_new_tags_only(self.pending_new_tags)
                logger.debug(f"增量同步: 插入 {inserted} 个新标签")
                self.pending_new_tags.clear()

            # 同步频率更新
            if self.pending_freq_ops:
                updated = self.sqlite.apply_frequency_ops(self.pending_freq_ops)
                logger.debug(f"增量同步: 更新 {updated} 个标签频率")
                self.pending_freq_ops.clear()

            self.illusts_since_sync = 0
            return True

        except Exception as e:
            logger.error(f"增量同步到 SQLite 失败: {e}")
            return False

    def force_sync(self) -> bool:
        """强制立即同步所有待处理的更新到数据库"""
        if self.mode == "sqlite":
            return self.sync_to_database()
        else:
            return self._json_storage.save_from_memory()

    def get_tag_frequency(self, tag_name: str) -> int:
        """获取标签频率"""
        for tag in self.tags:
            if tag.name == tag_name:
                return tag.frequency
        return 0

    # 保持向后兼容的方法
    def load_tags(self) -> List[PixivTag]:
        """从内存加载标签（向后兼容）"""
        return self.get_memory_tags()

    def save_tags(self, tags: List[PixivTag]):
        """保存标签到文件（向后兼容）"""
        self.tags = tags
        self.tag_names = {tag.name for tag in tags}
        self.save_from_memory()

    def append_tags(self, new_tags: List[PixivTag]):
        """追加新标签到内存（向后兼容）"""
        self.add_tags_to_memory(new_tags)

    def append_tags_to_file(self, new_tags: List[PixivTag]):
        """追加新标签到现有文件（向后兼容）"""
        try:
            existing_tags = self.load_tags()

            # 去重：基于标签名
            existing_names = {tag.name for tag in existing_tags}
            unique_new_tags = [
                tag for tag in new_tags if tag.name not in existing_names
            ]

            logger.info(
                f"Found {len(new_tags)} total new tags, {len(unique_new_tags)} are unique"
            )

            if not unique_new_tags:
                logger.info("No new unique tags to add")
                return

            all_tags = existing_tags + unique_new_tags
            self.save_tags(all_tags)
            logger.info(
                f"Successfully added {len(unique_new_tags)} new tags. Total: {len(all_tags)}"
            )

        except Exception as e:
            logger.error(f"Failed to append tags: {e}")
            # 尝试保存新标签到备份文件
            if self.mode == "json":
                try:
                    backup_path = f"{self.json_path}.new_tags"
                    backup_data = {"tags": [tag.to_dict() for tag in new_tags]}
                    os.makedirs(os.path.dirname(backup_path), exist_ok=True)
                    with open(backup_path, "w", encoding="utf-8") as f:
                        json.dump(backup_data, f, ensure_ascii=False, indent=2)
                    logger.info(f"Saved new tags to backup file: {backup_path}")
                except Exception as backup_e:
                    logger.error(f"Failed to save backup: {backup_e}")
            raise
