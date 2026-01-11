import hashlib
import logging
import time
from datetime import datetime
from typing import Dict, Optional

import httpx

logger = logging.getLogger(__name__)


class NetworkClient:
    """网络客户端，自动处理认证和错误重试"""

    def __init__(self, wait_time_429: int = 300, max_429_retries: int = 3):
        self.session = httpx.Client(timeout=30.0)
        self.access_token: Optional[str] = None
        self._429_wait_time = wait_time_429  # 429等待时间（秒）
        self._max_429_retries = max_429_retries  # 最大429重试次数

    def _check_stop_signal(self):
        """检查全局停止信号"""
        try:
            # 导入main模块的全局变量
            import main

            return getattr(main, "should_stop", False)
        except (ImportError, AttributeError):
            return False

    def _generate_fresh_headers(self) -> Dict[str, str]:
        """生成新的请求头（每次请求都重新生成时间戳和哈希）"""
        current_time = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S+00:00")

        # 生成客户端哈希
        hash_string = (
            current_time
            + "28c1fdd170a5204386cb1313c7077b34f83e4aaf4aa829ce78c231e05b0bae2c"
        )
        client_hash = hashlib.md5(hash_string.encode()).hexdigest()

        return {
            "User-Agent": "PixivIOSApp/6.7.1 (iOS 14.6; iPhone10,3) AppleWebKit/605.1.15",
            "X-Client-Time": current_time,
            "X-Client-Hash": client_hash,
            "App-OS": "ios",
            "App-OS-Version": "14.6",
            "App-Version": "7.13.3",
            "Accept-Language": "zh-CN",
            "Accept": "application/json",
            "Content-Type": "application/json",
        }

    def _add_auth_headers(self, headers: Dict[str, str]) -> Dict[str, str]:
        """添加认证头"""
        if self.access_token:
            headers["Authorization"] = f"Bearer {self.access_token}"
        return headers

    def _is_oauth_error(self, response: httpx.Response) -> bool:
        """检查是否为 OAuth 认证错误"""
        if response.status_code != 400:
            return False

        try:
            error_data = response.json()
            error_message = error_data.get("error", {}).get("message", "")
            return "OAuth" in error_message or "access token" in error_message.lower()
        except:
            return False

    def _refresh_token(self):
        """刷新 access_token，需要在外部实现具体逻辑"""
        logger.warning("Token refresh needed, but AuthAPI should handle this")
        raise RuntimeError("Token refresh failed - AuthAPI should handle this")

    def get(
        self,
        endpoint: str,
        params: Dict = None,
        headers: Dict = None,
        retry_count: int = 0,
    ) -> Dict:
        """GET 请求，自动处理 400 错误和 token 刷新"""
        url = f"https://app-api.pixiv.net{endpoint}"

        # 合并请求头：每次都生成新的基础头 + 认证头 + 自定义头
        merged_headers = self._add_auth_headers(self._generate_fresh_headers())
        if headers:
            merged_headers.update(headers)  # 自定义头覆盖默认头

        try:
            logger.debug(f"GET {url} with params: {params}")
            if headers:
                logger.debug(f"Custom headers: {headers}")
            response = self.session.get(url, headers=merged_headers, params=params)

            # 自动处理 429 错误
            if response.status_code == 429:
                return self._handle_429_error(url, merged_headers, params, retry_count)

            # 自动处理 400 错误
            if response.status_code == 400 and self._is_oauth_error(response):
                if retry_count < 1:
                    logger.info("OAuth error detected, attempting token refresh")
                    self._refresh_token()
                    merged_headers = self._add_auth_headers(
                        self._generate_fresh_headers()
                    )
                    if headers:
                        merged_headers.update(headers)
                    response = self.session.get(
                        url, headers=merged_headers, params=params
                    )

            response.raise_for_status()
            return response.json()

        except httpx.HTTPStatusError as e:
            logger.error(f"HTTP error: {e.response.status_code} - {e.response.text}")
            raise
        except Exception as e:
            logger.error(f"Network error: {e}")
            raise

    def post(self, endpoint: str, data: Dict = None, form_data: bool = False) -> Dict:
        """POST 请求"""
        url = endpoint
        headers = self._generate_fresh_headers()

        # POST 请求需要不同的 Content-Type
        if form_data:
            headers["Content-Type"] = "application/x-www-form-urlencoded"

        try:
            logger.debug(f"POST {url} with data: {data}")
            if form_data:
                response = self.session.post(url, data=data, headers=headers)
            else:
                response = self.session.post(url, json=data, headers=headers)

            response.raise_for_status()
            return response.json()

        except httpx.HTTPStatusError as e:
            logger.error(f"HTTP error: {e.response.status_code} - {e.response.text}")
            raise
        except Exception as e:
            logger.error(f"Network error: {e}")
            raise

    def _handle_429_error(
        self, url: str, headers: Dict, params: Dict, retry_count: int
    ) -> Dict:
        """处理429错误（请求过多），等待指定时间后重试"""

        if retry_count >= self._max_429_retries:
            logger.error(f"429错误重试次数已达上限 ({self._max_429_retries})，停止请求")
            raise httpx.HTTPStatusError(
                f"Too Many Requests: exceeded max retry limit",
                request=None,
                response=None,
            )

        wait_minutes = self._429_wait_time // 60
        wait_seconds = self._429_wait_time % 60

        logger.warning(
            f"🚫 检测到429错误（请求过多），等待 {wait_minutes} 分 {wait_seconds} 秒后重试 (第 {retry_count + 1}/{self._max_429_retries} 次)"
        )
        logger.info("💡 这是Pixiv API的速率限制，请耐心等待...")

        # 显示倒计时，同时检查全局停止信号
        remaining_seconds = self._429_wait_time
        while remaining_seconds > 0:
            mins, secs = divmod(remaining_seconds, 60)
            # 使用 carriage return 覆盖当前行，实现动态更新
            print(
                f"\r⏳ 等待中: {mins:02d}:{secs:02d} (剩余 {remaining_seconds} 秒)",
                end="",
                flush=True,
            )
            if self._check_stop_signal():
                logger.info("检测到退出信号，正在退出429等待...")
                raise KeyboardInterrupt("用户中断429等待")
            time.sleep(0.1)
            remaining_seconds -= 0.1

        print()  # 换行

        # 如果收到停止信号，抛出 KeyboardInterrupt
        if self._check_stop_signal():
            logger.info("检测到退出信号，正在退出429等待...")
            raise KeyboardInterrupt("用户中断429等待")

        logger.info("✅ 等待结束，重新发送请求...")

        # 重新生成请求头（时间戳更新）
        new_headers = self._add_auth_headers(self._generate_fresh_headers())
        new_headers.update(headers)

        try:
            response = self.session.get(url, headers=new_headers, params=params)

            # 如果还是429错误，递归处理
            if response.status_code == 429:
                return self._handle_429_error(url, headers, params, retry_count + 1)

            response.raise_for_status()
            logger.info("✅ 请求成功！")
            return response.json()

        except Exception as e:
            logger.error(f"429等待后重试失败: {e}")
            raise

    def close(self):
        """关闭客户端"""
        self.session.close()
