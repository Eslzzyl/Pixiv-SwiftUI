import logging
import os
import signal
import sys

from dotenv import load_dotenv
from src.api.auth import AuthAPI
from src.api.client import NetworkClient
from src.api.search import SearchAPI
from src.recommendation_collector import RecommendationBasedCollector
from src.storage import TagStorage

# 加载环境变量
load_dotenv()

# 配置日志
log_level = getattr(logging, os.getenv("LOG_LEVEL", "INFO").upper())
log_file = os.getenv("LOG_FILE_PATH", "pixiv_tags.log")

logging.basicConfig(
    level=log_level,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.FileHandler(log_file, encoding="utf-8"),
        logging.StreamHandler(sys.stdout),
    ],
)

logger = logging.getLogger(__name__)

# 全局变量用于优雅退出
should_stop = False


def signal_handler(signum, frame):
    """处理 Ctrl+C 信号"""
    global should_stop
    should_stop = True
    logger.info("\n收到退出信号，正在优雅退出...")
    logger.info("数据已自动保存，程序将安全退出")


def get_should_stop():
    """获取停止标志"""
    return should_stop


def main():
    """主函数"""
    # 注册信号处理器
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    # 从环境变量读取配置
    max_depth = int(os.getenv("MAX_DEPTH", "3"))
    wait_time_429 = int(os.getenv("PIXIV_429_WAIT_TIME", "300"))  # 默认5分钟
    max_429_retries = int(os.getenv("PIXIV_429_MAX_RETRIES", "3"))  # 默认3次
    tags_file_path = os.getenv("TAGS_FILE_PATH", "data/tags.json")
    save_interval = int(os.getenv("SAVE_INTERVAL", "20"))

    logger.info("🚀 启动 Pixiv 标签收集器 - 推荐流深度优先模式")
    logger.info("按 Ctrl+C 可以安全退出程序")
    logger.info("💡 推荐模式为无状态，每次重启都会获取新的推荐内容")
    logger.info(
        f"⚙️  配置: 深度限制={max_depth}, 429等待={wait_time_429 // 60}分钟, 429重试={max_429_retries}次, 保存间隔={save_interval}个标签"
    )

    # 初始化组件
    try:
        client = NetworkClient(
            wait_time_429=wait_time_429, max_429_retries=max_429_retries
        )
        auth_api = AuthAPI(client)
        search_api = SearchAPI(client)
        storage = TagStorage(tags_file_path)

        # 设置自动 token 刷新
        auth_api.setup_token_refresh()

        # 认证
        logger.info("Authenticating with refresh token...")
        auth_api.login_with_refresh_token()
        logger.info("Authentication successful")

        # 加载现有标签到内存
        initial_count = storage.load_to_memory()
        logger.info(f"Loaded {initial_count} existing tags from storage")

        # 使用推荐流收集器
        logger.info(f"🎯 使用推荐流模式 (深度限制: {max_depth})")
        collector = RecommendationBasedCollector(
            search_api, storage, max_depth=max_depth
        )
        collector.load_existing_data()
        collector.set_stop_flag(get_should_stop)

        # 收集新标签
        logger.info("开始从推荐流深度优先收集标签...")
        new_tags_count = collector.collect_from_recommendations()

        # 最终统计
        final_count = storage.get_memory_count()

        # 分析翻译统计和频率统计
        all_tags = storage.get_memory_tags()
        translated_count = sum(1 for tag in all_tags if tag.official_translation)
        total_frequency = sum(tag.frequency for tag in all_tags)
        avg_frequency = total_frequency / len(all_tags) if all_tags else 0

        logger.info("🎉 收集完成！")
        logger.info(f"发现新标签: {new_tags_count} 个，总计: {final_count} 个")
        logger.info(
            f"频率统计: 总出现次数 {total_frequency}，平均频率 {avg_frequency:.1f}"
        )
        # 翻译统计，避免除零错误
        if final_count > 0:
            translation_percentage = translated_count / final_count * 100
            logger.info(
                f"翻译统计: {translated_count}/{final_count} 个标签有翻译 ({translation_percentage:.1f}%)"
            )
        else:
            logger.info("翻译统计: 没有标签数据")

    except KeyboardInterrupt:
        logger.info("用户中断程序，正在保存数据...")
        if "storage" in locals():
            try:
                storage.save_from_memory()
                logger.info(f"数据已保存！总共 {storage.get_memory_count()} 个标签")
            except Exception as e:
                logger.error(f"保存数据时出错: {e}")

        logger.info("用户中断程序，已退出")
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        # 尝试保存数据
        if "storage" in locals():
            try:
                storage.save_from_memory()
                logger.info(
                    f"错误退出前已保存数据：{storage.get_memory_count()} 个标签"
                )
            except Exception as save_e:
                logger.error(f"错误退出前保存数据失败: {save_e}")

        raise
    finally:
        # 清理资源
        if "client" in locals():
            client.close()
        logger.info("Pixiv Tags Collector finished")


if __name__ == "__main__":
    main()
