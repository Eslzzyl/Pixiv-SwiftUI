import logging
from typing import List, Dict
from .client import NetworkClient


logger = logging.getLogger(__name__)


class SearchAPI:
    """Pixiv 搜索 API"""

    def __init__(self, client: NetworkClient):
        self.client = client

    def search_autocomplete(self, word: str) -> List[Dict]:
        """
        搜索自动补全接口（包含翻译信息）

        Args:
            word: 搜索关键词

        Returns:
            标签列表，每个标签包含 name 和 translated_name
        """
        # 使用更完整的参数，参考 SwiftUI 项目的实现
        params = {"word": word, "merge_plain_keyword_results": "true"}

        try:
            # 使用默认的请求头（已在 client.py 中设置）
            result = self.client.get("/v2/search/autocomplete", params=params)
            tags = result.get("tags", [])

            # 添加调试信息，查看返回的数据结构
            sample_tags_with_translation = [
                tag for tag in tags if tag.get("translated_name")
            ]

            # 为特定种子词打印完整调试信息
            if word in ["1", "100", "day", "challenge", "創作", "本家", "3DCG"]:
                logger.info(f"=== DEBUG for word '{word}' ===")
                logger.info(f"Total tags returned: {len(tags)}")
                logger.info(
                    f"Tags with translation: {len(sample_tags_with_translation)}"
                )

                if sample_tags_with_translation:
                    for tag in sample_tags_with_translation[:3]:
                        logger.info(
                            f"  '{tag.get('name')}' -> '{tag.get('translated_name')}'"
                        )
                elif tags:
                    logger.info("No translations found. Sample tag structures:")
                    for i, tag in enumerate(tags[:3]):
                        logger.info(f"  Tag {i}: {tag}")
                        # 检查是否有其他可能的翻译字段
                        for key in tag.keys():
                            if "trans" in key.lower() or "name" in key.lower():
                                logger.info(f"    Key '{key}': {tag[key]}")
                logger.info("=== END DEBUG ===")
            else:
                # 只为其他词提供简要信息
                if sample_tags_with_translation:
                    logger.debug(
                        f"Found {len(sample_tags_with_translation)} tags with translation for '{word}'"
                    )
                elif tags:
                    logger.debug(f"No translation for '{word}' ({len(tags)} tags)")

            logger.debug(f"Autocomplete for '{word}' returned {len(tags)} tags total")
            return tags

        except Exception as e:
            logger.error(f"Failed to get autocomplete for '{word}': {e}")
            return []

    def search_autocomplete_v1(self, word: str) -> List[str]:
        """
        搜索自动补全接口 v1 版本（无翻译）

        Args:
            word: 搜索关键词

        Returns:
            候选标签名称列表
        """
        params = {"word": word}

        try:
            result = self.client.get("/v1/search/autocomplete", params=params)
            candidates = result.get("candidates", [])
            tag_names = [
                candidate.get("tag_name", "")
                for candidate in candidates
                if candidate.get("tag_name")
            ]
            logger.debug(f"Autocomplete v1 for '{word}' returned {len(tag_names)} tags")
            return tag_names

        except Exception as e:
            logger.error(f"Failed to get autocomplete v1 for '{word}': {e}")
            return []
