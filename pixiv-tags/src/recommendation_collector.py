import logging
import os
import time
from dataclasses import dataclass
from typing import Dict, List, Optional

from .api.search import SearchAPI
from .models import PixivTag

logger = logging.getLogger(__name__)


@dataclass
class DFSNode:
    """深度优先搜索节点"""

    tag_name: str
    depth: int
    parent: Optional[str] = None


@dataclass
class CollectionStats:
    """收集统计信息"""

    tags_found: int = 0
    illusts_processed: int = 0
    tags_searched: int = 0
    depth_reached: int = 0


class RecommendationBasedCollector:
    """基于推荐流的深度优先标签收集器"""

    def __init__(
        self,
        search_api: SearchAPI,
        storage,
        max_depth: int = 3,
    ):
        self.search_api = search_api
        self.storage = storage
        self.max_depth = max_depth
        self.save_interval = int(
            os.getenv("SAVE_INTERVAL", "20")
        )  # 从环境变量读取保存间隔
        self.new_tags_count = 0

        # 统计信息
        self.stats = CollectionStats()

        # 停止标志
        self.should_stop_func = None

    def set_stop_flag(self, should_stop_func):
        """设置停止标志检查函数"""
        self.should_stop_func = should_stop_func

    def check_stop(self):
        """检查是否应该停止"""
        if hasattr(self, "should_stop_func") and self.should_stop_func():
            return True
        # 尝试从main模块获取全局停止标志
        try:
            import main

            return getattr(main, "should_stop", False)
        except (ImportError, AttributeError):
            return False

    def _should_save_now(self) -> bool:
        """检查是否应该现在保存（SQLite 模式下由 _dfs_collect_tags 处理）"""
        return False

    def _try_save(self, force: bool = False):
        """尝试保存（SQLite 模式：强制同步；JSON 模式：基于搜索次数）"""
        if force:
            if self.storage.mode == "sqlite":
                self.storage.force_sync()
                logger.info(
                    f"Force-saved {self.storage.get_memory_count()} tags to database"
                )
            else:
                self.storage.save_from_memory()
                logger.info(
                    f"Force-saved {self.storage.get_memory_count()} tags to file"
                )
            return True

        if self.storage.mode == "sqlite":
            # SQLite 模式：同步由 _dfs_collect_tags 中的搜索计数处理
            return True
        else:
            # JSON 模式：基于搜索次数触发保存
            if self.stats.tags_searched % self.save_interval == 0:
                try:
                    self.storage.save_from_memory()
                    logger.info(
                        f"Auto-saved {self.storage.get_memory_count()} tags to file"
                    )
                    return True
                except Exception as e:
                    logger.error(f"Failed to auto-save: {e}")
                    return False
        return False

    def _extract_tags_from_illust(self, illust: Dict) -> List[PixivTag]:
        """从插画数据中提取所有标签（包括已存在的）"""
        tags = []
        illust_tags = illust.get("tags", [])

        for tag_data in illust_tags:
            tag_name = tag_data.get("name")
            if tag_name:
                tag = PixivTag(
                    name=tag_name, official_translation=tag_data.get("translated_name")
                )
                tags.append(tag)

        return tags

    def _process_illusts(self, illusts: List[Dict], current_depth: int) -> List[str]:
        """处理插画列表，返回新发现的标签"""
        new_tag_names = []

        for illust in illusts:
            # 检查停止标志
            if self.check_stop():
                break

            illust_id = illust.get("id")
            if not illust_id:
                continue
            self.stats.illusts_processed += 1

            # 获取插画的所有标签
            illust_tags = illust.get("tags", [])
            if not illust_tags:
                continue

            # 分类标签：新增和重复
            new_tags_for_illust = []
            existing_tags_for_illust = []
            existing_tag_details = []  # 存储重复标签的详细信息（包含频率）

            for tag_data in illust_tags:
                tag_name = tag_data.get("name")
                if not tag_name:
                    continue

                if not self.storage.is_tag_in_memory(tag_name):
                    # 新标签
                    tag = PixivTag(
                        name=tag_name,
                        official_translation=tag_data.get("translated_name"),
                        frequency=1,  # 新标签初始频率为1
                    )
                    new_tags_for_illust.append(tag)
                    new_tag_names.append(tag_name)
                else:
                    # 重复标签，记录详细信息并增加频率
                    existing_tags_for_illust.append(tag_name)
                    # 获取当前频率并更新
                    current_freq = self.storage.get_tag_frequency(tag_name)
                    existing_tag_details.append(
                        f"'{tag_name}'(频率:{current_freq + 1})"
                    )
                    self.storage.increment_tag_frequency(tag_name, 1)

            # 将新标签添加到内存
            if new_tags_for_illust:
                added_count = self.storage.add_tags_to_memory(new_tags_for_illust)
                self.new_tags_count += added_count
                self.stats.tags_found += added_count

            # 输出汇总日志
            if new_tags_for_illust or existing_tags_for_illust:
                new_tag_strs = []
                for tag in new_tags_for_illust:
                    if tag.official_translation:
                        new_tag_strs.append(
                            f"'{tag.name}'->'{tag.official_translation}'(频率:{tag.frequency})"
                        )
                    else:
                        new_tag_strs.append(f"'{tag.name}'(频率:{tag.frequency})")

                # 使用包含频率的详细信息
                existing_tag_strs = existing_tag_details[:5]  # 限制重复标签显示数量
                if len(existing_tags_for_illust) > 5:
                    existing_tag_strs.append(
                        f"...等{len(existing_tags_for_illust) - 5}个"
                    )

                if new_tags_for_illust and existing_tags_for_illust:
                    new_tags_summary = ", ".join(new_tag_strs)
                    existing_tags_summary = ", ".join(existing_tag_strs)
                    logger.info(
                        f"[深度{current_depth}] 插画{illust_id}: 新增{len(new_tags_for_illust)}个标签 {new_tags_summary} | "
                        f"重复{len(existing_tags_for_illust)}个标签 {existing_tags_summary}"
                    )
                elif new_tags_for_illust:
                    new_tags_summary = ", ".join(new_tag_strs)
                    logger.info(
                        f"[深度{current_depth}] 插画{illust_id}: 新增{len(new_tags_for_illust)}个标签 {new_tags_summary}"
                    )
                elif existing_tags_for_illust:
                    existing_tags_summary = ", ".join(existing_tag_strs)
                    logger.debug(
                        f"[深度{current_depth}] 插画{illust_id}: 重复{len(existing_tags_for_illust)}个标签 {existing_tags_summary}"
                    )

        return new_tag_names

    def _dfs_collect_tags(self, start_tags: List[str]) -> CollectionStats:
        """深度优先收集标签"""
        # 使用栈实现深度优先搜索
        stack: List[DFSNode] = []

        # 初始化栈，将起始标签作为深度0
        for tag_name in start_tags:
            stack.append(DFSNode(tag_name=tag_name, depth=0))

        while stack and not self.check_stop():
            node = stack.pop()
            current_tag = node.tag_name
            current_depth = node.depth

            # 更新统计
            self.stats.tags_searched += 1
            self.stats.depth_reached = max(self.stats.depth_reached, current_depth)

            logger.info(f"搜索标签 '{current_tag}' (深度: {current_depth})")

            # 按标签搜索插画
            time.sleep(1)  # 请求间隔
            try:
                illusts = self.search_api.search_illust_by_tag(current_tag, limit=20)
            except Exception as e:
                if "429" in str(e) or "Too Many Requests" in str(e):
                    logger.error(f"429错误处理失败: {e}")
                    logger.info("程序将尝试从其他标签继续...")
                    continue
                else:
                    logger.error(f"搜索标签 '{current_tag}' 时出错: {e}")
                    continue

            if not illusts:
                logger.debug(f"标签 '{current_tag}' 没有找到相关插画")
                continue

            # 处理插画，提取新标签
            new_tag_names = self._process_illusts(illusts, current_depth)

            # 将新标签加入栈（深度+1）
            if current_depth < self.max_depth:
                for tag_name in new_tag_names:
                    stack.append(
                        DFSNode(
                            tag_name=tag_name,
                            depth=current_depth + 1,
                            parent=current_tag,
                        )
                    )

            # 每 N 次搜索同步一次（基于搜索次数，而非插画计数）
            self.stats.tags_searched += 1
            if self.stats.tags_searched % self.save_interval == 0:
                if self.storage.mode == "sqlite":
                    self.storage.sync_to_database()
                    logger.debug(
                        f"自动同步: 已搜索 {self.stats.tags_searched} 个标签，"
                        f"待同步新标签 {len(self.storage.pending_new_tags)}，"
                        f"待同步频率操作 {len(self.storage.pending_freq_ops)}"
                    )
                else:
                    self.storage.save_from_memory()
                    logger.info(
                        f"Auto-saved {self.storage.get_memory_count()} tags to file"
                    )

            # 每10个搜索输出一次进度
            if self.stats.tags_searched % 10 == 0:
                logger.info(
                    f"📈 进度: 已搜索 {self.stats.tags_searched} 个标签，"
                    f"发现 {self.stats.tags_found} 个新标签，"
                    f"处理 {self.stats.illusts_processed} 个插画，"
                    f"最大深度 {self.stats.depth_reached}"
                )

        return self.stats

    def collect_from_recommendations(self) -> int:
        """从推荐流开始深度优先收集标签"""
        logger.info(f"开始基于推荐流的深度优先标签收集 (最大深度: {self.max_depth})")

        start_time = time.time()
        initial_tag_count = self.storage.get_memory_count()

        try:
            # 1. 获取推荐插画作为起点
            logger.info("获取推荐插画...")
            try:
                recommended_illusts = self.search_api.get_recommended_illusts(limit=30)
            except Exception as e:
                if "429" in str(e) or "Too Many Requests" in str(e):
                    logger.error(f"获取推荐插画时遇到429错误: {e}")
                    logger.error("请稍后再试，或减少请求频率")
                    return 0
                else:
                    logger.error(f"获取推荐插画失败: {e}")
                    return 0

            if not recommended_illusts:
                logger.error("无法获取推荐插画，尝试备用方案...")
                return 0

            logger.info(f"获取到 {len(recommended_illusts)} 个推荐插画")

            # 2. 从推荐插画中提取初始标签
            initial_tags = self._process_illusts(recommended_illusts, 0)
            logger.info(f"从推荐插画中提取到 {len(initial_tags)} 个初始标签")

            if not initial_tags:
                logger.warning("推荐插画中没有发现新标签")
                return 0

            # 3. 深度优先搜索
            logger.info(f"开始深度优先搜索，初始标签数量: {len(initial_tags)}")
            stats = self._dfs_collect_tags(initial_tags)

            # 4. 强制保存最终结果
            self._try_save(force=True)

            # 5. 输出统计信息
            final_tag_count = self.storage.get_memory_count()
            total_new_count = final_tag_count - initial_tag_count
            total_time = time.time() - start_time

            # 频率统计
            all_tags = self.storage.get_memory_tags()
            total_frequency = sum(tag.frequency for tag in all_tags)
            avg_frequency = total_frequency / len(all_tags) if all_tags else 0

            logger.info("🎉 深度优先收集完成！")
            logger.info(f"⏱️  总用时: {total_time / 60:.1f} 分钟")
            logger.info(f"🏷️  新发现标签: {total_new_count} 个")
            logger.info(f"📊 总标签数: {final_tag_count} 个")
            logger.info(
                f"📈 频率统计: 总出现次数 {total_frequency}，平均频率 {avg_frequency:.1f}"
            )
            logger.info(f"🔍 搜索标签数: {stats.tags_searched} 个")
            logger.info(f"🎨 处理插画数: {stats.illusts_processed} 个")
            logger.info(f"📏 最大深度: {stats.depth_reached}")

            if total_time > 0:
                tags_per_minute = (stats.tags_searched * 60) / total_time
                logger.info(f"⚡ 搜索速度: {tags_per_minute:.1f} 标签/分钟")

            return total_new_count

        except Exception as e:
            logger.error(f"深度优先收集过程中出错: {e}")
            # 尝试保存已收集的数据
            self._try_save(force=True)
            raise

    def load_existing_data(self):
        """加载现有数据（推荐模式为无状态，不需要加载进度）"""
        existing_tags = self.storage.get_memory_tags()
        logger.info(f"当前存储中有 {len(existing_tags)} 个标签")
        # 推荐模式是无状态的，不需要维护去重集合
