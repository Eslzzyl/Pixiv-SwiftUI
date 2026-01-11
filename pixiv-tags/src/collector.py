import time
import logging
from typing import List
from .models import PixivTag
from .api.search import SearchAPI


logger = logging.getLogger(__name__)


class TagCollector:
    """标签收集器"""

    def __init__(self, search_api: SearchAPI, storage):
        self.search_api = search_api
        self.storage = storage
        self.save_interval = 50  # 每收集 50 个新标签保存一次
        self.new_tags_count = 0

    def set_stop_flag(self, should_stop_func):
        """设置停止标志检查函数"""
        self.should_stop_func = should_stop_func

    def set_save_interval(self, interval: int):
        """设置保存间隔"""
        self.save_interval = interval

    def check_stop(self):
        """检查是否应该停止"""
        if hasattr(self, "should_stop_func") and self.should_stop_func():
            return True
        return globals().get("should_stop", False)

    def _should_save_now(self) -> bool:
        """检查是否应该现在保存"""
        return self.new_tags_count >= self.save_interval

    def _try_save(self, force: bool = False):
        """尝试保存（如果达到保存间隔或强制保存）"""
        if force or self._should_save_now():
            try:
                self.storage.save_from_memory()
                logger.info(
                    f"Auto-saved {self.storage.get_memory_count()} tags to file"
                )
                self.new_tags_count = 0  # 重置计数器
                return True
            except Exception as e:
                logger.error(f"Failed to auto-save: {e}")
                return False
        return False

    def load_existing_tags(self, tags: List[PixivTag]):
        """加载已存在的标签，建立去重集合（现在使用存储的内存缓存）"""
        logger.info(f"Using storage with {self.storage.get_memory_count()} loaded tags")

    def collect_from_autocomplete(
        self, seed_words: List[str], progress_manager=None
    ) -> int:
        """从自动补全接口收集标签，返回总共收集的新标签数量"""
        import time
        from datetime import datetime

        processed_count = 0
        total_found_count = 0
        start_time = time.time()

        initial_tag_count = self.storage.get_memory_count()
        total_seed_count = len(seed_words)

        logger.info(
            f"Starting collection with {initial_tag_count} existing tags in memory"
        )
        if progress_manager:
            progress_manager.print_progress_summary()

        for i, word in enumerate(seed_words, 1):
            # 检查是否需要停止
            if self.check_stop():
                logger.info("收到停止信号，提前结束收集")
                break

            try:
                # 显示进度信息
                actual_index = progress_manager.current_index if progress_manager else i
                logger.info(
                    f"Processing seed word {actual_index}/{total_seed_count}: '{word}'"
                )

                # 获取自动补全结果
                tags_data = self.search_api.search_autocomplete(word)

                word_new_count = 0
                for tag_data in tags_data:
                    tag_name = tag_data["name"]
                    if not self.storage.is_tag_in_memory(tag_name):
                        tag = PixivTag.from_api_response(tag_data)
                        # 如果有翻译，记录详细信息用于调试
                        if tag.official_translation:
                            logger.info(
                                f"Found new tag WITH TRANSLATION: '{tag_name}' -> '{tag.official_translation}'"
                            )
                        else:
                            logger.info(
                                f"Found new tag: '{tag_name}' -> {tag.official_translation}"
                            )
                        self.storage.add_tags_to_memory([tag])
                        self.new_tags_count += 1
                        word_new_count += 1
                        total_found_count += 1

                if word_new_count > 0:
                    logger.info(f"Found {word_new_count} new tags from '{word}'")

                # 标记该种子词为已处理
                if progress_manager:
                    if not progress_manager.mark_processed(word):
                        logger.warning(f"Failed to save progress for word: '{word}'")

                # 尝试自动保存
                self._try_save()

                # 计算处理速度和预估时间
                if i % 10 == 0 and progress_manager:  # 每10个词统计一次
                    elapsed_time = time.time() - start_time
                    words_per_minute = (
                        (i * 60) / elapsed_time if elapsed_time > 0 else 0
                    )
                    eta = progress_manager.get_eta(words_per_minute)

                    if words_per_minute > 0:
                        logger.info(
                            f"📈 处理速度: {words_per_minute:.1f} 词/分钟，预计剩余时间: {eta}"
                        )

                # 请求间隔 0.5 秒
                if i < len(seed_words):
                    time.sleep(0.5)

            except Exception as e:
                logger.error(f"Error processing word '{word}': {e}")
                # 即使出错也要标记为已处理，避免重复处理有问题的种子词
                if progress_manager:
                    progress_manager.mark_processed(word)
                continue

        # 强制保存最终结果
        self._try_save(force=True)

        final_tag_count = self.storage.get_memory_count()
        total_new_count = final_tag_count - initial_tag_count

        # 计算总时间
        total_time = time.time() - start_time

        logger.info(f"Collection complete:")
        if progress_manager:
            progress_manager.print_progress_summary()
        else:
            logger.info(f"  - Processed {i}/{total_seed_count} seed words")
        logger.info(
            f"  - Found {total_new_count} new tags (total: {total_found_count} including duplicates)"
        )
        logger.info(f"  - Final tag count: {final_tag_count}")
        logger.info(f"  - Total time: {total_time / 60:.1f} minutes")

        # 计算平均处理速度
        if total_time > 0:
            avg_speed = (i * 60) / total_time
            logger.info(f"  - Average speed: {avg_speed:.1f} words/minute")

        return total_new_count

    def collect_from_autocomplete_v1(self, seed_words: List[str]) -> int:
        """从自动补全 v1 接口收集标签，返回总共收集的新标签数量"""
        processed_count = 0
        total_found_count = 0

        initial_tag_count = self.storage.get_memory_count()
        logger.info(
            f"Starting collection (v1) with {initial_tag_count} existing tags in memory"
        )

        for word in seed_words:
            # 检查是否需要停止
            if self.check_stop():
                logger.info("收到停止信号，提前结束收集")
                break

            try:
                processed_count += 1
                logger.info(
                    f"Processing seed word {processed_count}/{len(seed_words)}: '{word}' (v1)"
                )

                # 获取自动补全结果
                tag_names = self.search_api.search_autocomplete_v1(word)

                word_new_count = 0
                for tag_name in tag_names:
                    if not self.storage.is_tag_in_memory(tag_name):
                        tag = PixivTag(name=tag_name)  # v1 接口没有翻译信息
                        self.storage.add_tags_to_memory([tag])
                        self.new_tags_count += 1
                        word_new_count += 1
                        total_found_count += 1
                        logger.info(f"Found new tag: '{tag_name}'")

                if word_new_count > 0:
                    logger.info(f"Found {word_new_count} new tags from '{word}' (v1)")

                # 尝试自动保存
                self._try_save()

                # 请求间隔 0.5 秒
                if processed_count < len(seed_words):
                    time.sleep(0.5)

            except Exception as e:
                logger.error(f"Error processing word '{word}' (v1): {e}")
                continue

        # 强制保存最终结果
        self._try_save(force=True)

        final_tag_count = self.storage.get_memory_count()
        total_new_count = final_tag_count - initial_tag_count

        logger.info(f"Collection v1 complete:")
        logger.info(f"  - Processed {processed_count}/{len(seed_words)} seed words")
        logger.info(
            f"  - Found {total_new_count} new tags (total: {total_found_count} including duplicates)"
        )
        logger.info(f"  - Final tag count: {final_tag_count}")

        return total_new_count
