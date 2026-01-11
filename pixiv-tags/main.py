import logging
import signal
import sys
import argparse
from src.api.client import NetworkClient
from src.api.auth import AuthAPI
from src.api.search import SearchAPI
from src.models import PixivTag
from src.storage import TagStorage
from src.collector import TagCollector
from src.progress import SeedProgress


# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.FileHandler("pixiv_tags.log", encoding="utf-8"),
        logging.StreamHandler(sys.stdout),
    ],
)

logger = logging.getLogger(__name__)

# 全局变量用于优雅退出
should_stop = False
progress_manager = None


def signal_handler(signum, frame):
    """处理 Ctrl+C 信号"""
    global should_stop, progress_manager
    should_stop = True
    logger.info("\n收到退出信号，正在优雅退出...")
    logger.info("当前进度已保存，程序将安全退出")
    if progress_manager:
        progress_manager.save_progress()
        progress_manager.print_progress_summary()


def get_should_stop():
    """获取停止标志"""
    return should_stop


def generate_seed_words() -> list[str]:
    """生成种子词：日文假名 + 英文字母 + 数字"""
    seed_words = []

    # 日文平假名 (ぁ-ゖ)
    hiragana = [chr(i) for i in range(0x3041, 0x3097)]
    seed_words.extend(hiragana)

    # 日文片假名 (ァ-ヶ)
    katakana = [chr(i) for i in range(0x30A1, 0x30F7)]
    seed_words.extend(katakana)

    # 英文小写字母
    english_lower = [chr(i) for i in range(ord("a"), ord("z") + 1)]
    seed_words.extend(english_lower)

    # 英文大写字母
    english_upper = [chr(i) for i in range(ord("A"), ord("Z") + 1)]
    seed_words.extend(english_upper)

    # 数字
    numbers = [str(i) for i in range(10)]
    seed_words.extend(numbers)

    logger.info(f"Generated {len(seed_words)} seed words:")
    logger.info(f"  - Hiragana: {len(hiragana)}")
    logger.info(f"  - Katakana: {len(katakana)}")
    logger.info(f"  - English lower: {len(english_lower)}")
    logger.info(f"  - English upper: {len(english_upper)}")
    logger.info(f"  - Numbers: {len(numbers)}")

    return seed_words


def parse_args():
    """解析命令行参数"""
    parser = argparse.ArgumentParser(description="Pixiv Tags Collector")
    parser.add_argument("--reset", action="store_true", help="重置进度，从头开始收集")
    parser.add_argument("--status", action="store_true", help="显示当前进度状态")
    return parser.parse_args()


def main():
    """主函数"""
    global progress_manager

    # 解析命令行参数
    args = parse_args()

    # 注册信号处理器
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    # 处理 --status 参数
    if args.status:
        temp_progress = SeedProgress("data/seed_progress.json")
        all_seed_words = generate_seed_words()
        remaining = temp_progress.load_progress(all_seed_words)
        temp_progress.print_progress_summary()
        return

    # 处理 --reset 参数
    if args.reset:
        temp_progress = SeedProgress("data/seed_progress.json")
        if temp_progress.reset_progress():
            logger.info("✅ 进度已重置，下次运行将从头开始")
        else:
            logger.error("❌ 重置进度失败")
        return

    logger.info("Starting Pixiv Tags Collector")
    logger.info("按 Ctrl+C 可以安全退出程序")
    logger.info("💡 使用 --status 查看进度，--reset 重置进度")

    # 初始化组件
    try:
        client = NetworkClient()
        auth_api = AuthAPI(client)
        search_api = SearchAPI(client)
        storage = TagStorage("data/tags.json")
        collector = TagCollector(search_api, storage)

        # 设置自动 token 刷新
        auth_api.setup_token_refresh()

        # 认证
        logger.info("Authenticating with refresh token...")
        auth_api.login_with_refresh_token()
        logger.info("Authentication successful")

        # 加载现有标签到内存
        initial_count = storage.load_to_memory()
        collector.load_existing_tags([])  # 传递空列表，因为我们使用内存存储
        collector.set_stop_flag(get_should_stop)

        # 初始化进度管理器
        progress_manager = SeedProgress("data/seed_progress.json")

        # 生成完整的种子词列表
        all_seed_words = generate_seed_words()

        # 加载进度，获取剩余未处理的种子词
        remaining_seed_words = progress_manager.load_progress(all_seed_words)

        if not remaining_seed_words:
            logger.info("🎉 所有种子词都已处理完成！")
            logger.info("💡 使用 --reset 参数可以重新开始收集")
        else:
            # 收集新标签
            logger.info("Starting tag collection from autocomplete API...")
            new_tags_count = collector.collect_from_autocomplete(
                remaining_seed_words, progress_manager
            )

            # 最终统计
            final_count = storage.get_memory_count()

            # 分析翻译统计
            all_tags = storage.get_memory_tags()
            translated_count = sum(1 for tag in all_tags if tag.official_translation)

            logger.info(
                f"Collection complete! Added {new_tags_count} new tags. Total: {final_count}"
            )
            logger.info(
                f"Translation summary: {translated_count}/{final_count} tags have translations ({translated_count / final_count * 100:.1f}%)"
            )

            # 如果收集完成，清理进度文件
            if progress_manager.is_complete():
                logger.info("🎉 所有种子词处理完成！")
                progress_manager.reset_progress()
            else:
                logger.info("⏸️ 收集被中断，进度已保存")
                logger.info("💡 下次运行将从中断处继续")

    except KeyboardInterrupt:
        logger.info("用户中断程序，正在保存数据...")
        if "storage" in locals():
            try:
                storage.save_from_memory()
                logger.info(f"数据已保存！总共 {storage.get_memory_count()} 个标签")
            except Exception as e:
                logger.error(f"保存数据时出错: {e}")

        if progress_manager:
            progress_manager.save_progress()
            progress_manager.print_progress_summary()
            logger.info("⏸️ 进度已保存，下次运行将从中断处继续")

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

        if progress_manager:
            progress_manager.save_progress()

        raise
    finally:
        # 清理资源
        if "client" in locals():
            client.close()
        logger.info("Pixiv Tags Collector finished")


if __name__ == "__main__":
    main()
