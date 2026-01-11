import json
import os
import logging
from typing import List, Optional, Tuple


logger = logging.getLogger(__name__)


class SeedProgress:
    """种子词进度管理器"""

    def __init__(self, progress_file: str = "data/seed_progress.json"):
        self.progress_file = progress_file
        self.processed_words: set[str] = set()
        self.total_words = 0
        self.current_index = 0
        self.seed_words: List[str] = []

    def load_progress(self, seed_words: List[str]) -> List[str]:
        """
        加载进度并返回剩余未处理的种子词

        Args:
            seed_words: 完整的种子词列表

        Returns:
            剩余未处理的种子词列表
        """
        self.seed_words = seed_words
        self.total_words = len(seed_words)

        if os.path.exists(self.progress_file):
            try:
                with open(self.progress_file, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    self.processed_words = set(data.get("processed_words", []))
                    self.current_index = data.get("current_index", 0)

                logger.info(
                    f"📂 加载进度：已处理 {len(self.processed_words)}/{self.total_words} 个种子词"
                )

                # 返回未处理的种子词
                remaining_words = []
                for i, word in enumerate(seed_words):
                    if word not in self.processed_words:
                        remaining_words.append(word)
                    else:
                        self.current_index = i + 1

                logger.info(f"🔄 剩余 {len(remaining_words)} 个种子词需要处理")
                return remaining_words

            except Exception as e:
                logger.error(f"加载进度文件失败: {e}")
                logger.info("🔄 从头开始处理所有种子词")
                return seed_words
        else:
            logger.info("📝 没有进度文件，从头开始处理")
            return seed_words

    def mark_processed(self, word: str) -> bool:
        """
        标记一个种子词为已处理

        Args:
            word: 已处理的种子词

        Returns:
            是否成功保存进度
        """
        try:
            self.processed_words.add(word)

            # 更新当前索引
            try:
                self.current_index = self.seed_words.index(word) + 1
            except ValueError:
                pass

            return self.save_progress()
        except Exception as e:
            logger.error(f"标记进度失败: {e}")
            return False

    def save_progress(self) -> bool:
        """保存当前进度到文件"""
        try:
            # 确保目录存在
            progress_dir = os.path.dirname(self.progress_file)
            if progress_dir:  # 只有当目录不为空时才创建
                os.makedirs(progress_dir, exist_ok=True)

            data = {
                "processed_words": list(self.processed_words),
                "current_index": self.current_index,
                "total_words": self.total_words,
                "timestamp": self._get_timestamp(),
            }

            with open(self.progress_file, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=2)

            return True

        except Exception as e:
            logger.error(f"保存进度失败: {e}")
            return False

    def get_progress_info(self) -> dict:
        """获取当前进度信息"""
        return {
            "processed_count": len(self.processed_words),
            "total_count": self.total_words,
            "current_index": self.current_index,
            "progress_percentage": len(self.processed_words) / self.total_words * 100
            if self.total_words > 0
            else 0,
            "remaining_count": self.total_words - len(self.processed_words),
        }

    def is_complete(self) -> bool:
        """检查是否所有种子词都已处理"""
        return len(self.processed_words) >= self.total_words

    def reset_progress(self) -> bool:
        """重置进度"""
        try:
            self.processed_words.clear()
            self.current_index = 0
            if os.path.exists(self.progress_file):
                os.remove(self.progress_file)
            logger.info("🔄 进度已重置")
            return True
        except Exception as e:
            logger.error(f"重置进度失败: {e}")
            return False

    def _get_timestamp(self) -> str:
        """获取当前时间戳"""
        from datetime import datetime

        return datetime.now().isoformat()

    def print_progress_summary(self):
        """打印进度摘要"""
        info = self.get_progress_info()
        logger.info("📊 种子词处理进度:")
        logger.info(
            f"  ✅ 已处理: {info['processed_count']}/{info['total_count']} ({info['progress_percentage']:.1f}%)"
        )
        logger.info(f"  ⏳ 剩余: {info['remaining_count']} 个")
        logger.info(f"  📍 当前位置: {info['current_index']}")

    def get_eta(self, processed_per_minute: float) -> str:
        """
        估算剩余时间

        Args:
            processed_per_minute: 每分钟处理的种子词数量

        Returns:
            格式化的剩余时间字符串
        """
        remaining = self.get_progress_info()["remaining_count"]
        if processed_per_minute <= 0 or remaining <= 0:
            return "未知"

        minutes_remaining = remaining / processed_per_minute

        if minutes_remaining < 60:
            return f"{minutes_remaining:.0f} 分钟"
        else:
            hours = minutes_remaining / 60
            return f"{hours:.1f} 小时"
