import os
import logging
from typing import Optional
from dotenv import load_dotenv
from .client import NetworkClient


logger = logging.getLogger(__name__)


class AuthAPI:
    """Pixiv API 认证管理"""

    def __init__(self, client: NetworkClient):
        self.client = client
        load_dotenv()  # 加载 .env 文件
        self.refresh_token = os.getenv("REFRESH_TOKEN")

        if not self.refresh_token:
            raise ValueError("REFRESH_TOKEN not found in environment variables")

    def login_with_refresh_token(self) -> str:
        """使用 refresh_token 获取 access_token"""
        if not self.refresh_token:
            raise ValueError("No refresh token available")

        url = "https://oauth.secure.pixiv.net/auth/token"
        data = {
            "client_id": "MOBrBDS8blbauoSck0ZfDbtuzpyT",
            "client_secret": "lsACyCD94FhDUtGTXi3QzcFE2uU1hqtDaKeqrdwj",
            "grant_type": "refresh_token",
            "refresh_token": self.refresh_token,
            "get_secure_url": "true",
        }

        try:
            logger.info("Attempting to refresh access token")
            result = self.client.post(url, data=data, form_data=True)

            access_token = result.get("access_token")
            if not access_token:
                raise ValueError("No access token in response")

            self.client.access_token = access_token
            logger.info("Successfully obtained access token")
            return access_token

        except Exception as e:
            logger.error(f"Failed to refresh access token: {e}")
            raise

    def setup_token_refresh(self):
        """设置自动 token 刷新"""

        # 重写客户端的刷新方法
        def refresh_token():
            self.login_with_refresh_token()

        self.client._refresh_token = refresh_token
