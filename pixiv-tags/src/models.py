from dataclasses import dataclass
from typing import Optional, List


@dataclass
class PixivTag:
    """Pixiv 标签数据模型"""

    name: str
    official_translation: Optional[str] = None
    chinese_translation: str = ""
    english_translation: str = ""
    frequency: int = 0  # 标签出现频率

    @classmethod
    def from_api_response(cls, tag_data: dict) -> "PixivTag":
        """从 API 响应创建标签对象"""
        return cls(
            name=tag_data["name"],
            official_translation=tag_data.get("translated_name"),
            frequency=1,  # 新标签初始频率为1
        )

    def to_dict(self) -> dict:
        """转换为字典格式"""
        return {
            "name": self.name,
            "official_translation": self.official_translation,
            "chinese_translation": self.chinese_translation,
            "english_translation": self.english_translation,
            "frequency": self.frequency,
        }


@dataclass
class PixivIllust:
    """Pixiv 插画数据模型"""

    id: int
    title: str
    tags: List[PixivTag]
    user_id: int
    user_name: str

    @classmethod
    def from_api_response(cls, illust_data: dict) -> "PixivIllust":
        """从 API 响应创建插画对象"""
        # 解析标签
        tags = []
        for tag_data in illust_data.get("tags", []):
            tag = PixivTag.from_api_response(tag_data)
            tags.append(tag)

        # 解析用户信息
        user_data = illust_data.get("user", {})
        user_id = user_data.get("id", 0)
        user_name = user_data.get("name", "")

        return cls(
            id=illust_data["id"],
            title=illust_data.get("title", ""),
            tags=tags,
            user_id=user_id,
            user_name=user_name,
        )

    def get_tag_names(self) -> List[str]:
        """获取所有标签名称"""
        return [tag.name for tag in self.tags]
