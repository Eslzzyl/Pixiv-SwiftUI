from dataclasses import dataclass
from typing import Optional


@dataclass
class PixivTag:
    """Pixiv 标签数据模型"""

    name: str
    official_translation: Optional[str] = None
    chinese_translation: str = ""
    english_translation: str = ""

    @classmethod
    def from_api_response(cls, tag_data: dict) -> "PixivTag":
        """从 API 响应创建标签对象"""
        return cls(
            name=tag_data["name"], official_translation=tag_data.get("translated_name")
        )

    def to_dict(self) -> dict:
        """转换为字典格式"""
        return {
            "name": self.name,
            "official_translation": self.official_translation,
            "chinese_translation": self.chinese_translation,
            "english_translation": self.english_translation,
        }
