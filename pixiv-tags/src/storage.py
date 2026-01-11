import json
import os
import logging
from typing import List
from .models import PixivTag


logger = logging.getLogger(__name__)


class TagStorage:
    """标签数据存储管理"""

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
        """将新标签添加到内存中"""
        unique_new_tags = [tag for tag in new_tags if tag.name not in self.tag_names]

        if not unique_new_tags:
            return 0

        self.tags.extend(unique_new_tags)
        for tag in unique_new_tags:
            self.tag_names.add(tag.name)

        logger.debug(
            f"Added {len(unique_new_tags)} new tags to memory. Total: {len(self.tags)}"
        )
        return len(unique_new_tags)

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

    def get_memory_count(self) -> int:
        """获取内存中的标签数量"""
        return len(self.tags)

    def get_memory_tags(self) -> List[PixivTag]:
        """获取内存中的所有标签"""
        return self.tags.copy()

    def is_tag_in_memory(self, tag_name: str) -> bool:
        """检查标签是否已在内存中"""
        return tag_name in self.tag_names

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

    def append_tags(self, new_tags: List[PixivTag]):
        """追加新标签到现有文件"""
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
            try:
                backup_path = f"{self.file_path}.new_tags"
                backup_data = {"tags": [tag.to_dict() for tag in new_tags]}
                os.makedirs(os.path.dirname(backup_path), exist_ok=True)
                with open(backup_path, "w", encoding="utf-8") as f:
                    json.dump(backup_data, f, ensure_ascii=False, indent=2)
                logger.info(f"Saved new tags to backup file: {backup_path}")
            except Exception as backup_e:
                logger.error(f"Failed to save backup: {backup_e}")
            raise
