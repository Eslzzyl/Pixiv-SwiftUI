#!/usr/bin/env python3
"""
Pixiv OAuth 登录调试工具
用于验证请求格式和响应

使用方法：
1. 替换 REFRESH_TOKEN 变量为您的实际 token
2. 运行此脚本: python3 test_oauth.py
3. 查看详细的请求和响应信息
"""

import json
from urllib.parse import urlencode

import requests

# 配置
OAUTH_URL = "https://oauth.secure.pixiv.net/auth/token"
CLIENT_ID = "MOBrBDS8blbauoSck0ZfDbtuzpyT"
CLIENT_SECRET = "lsACyCD94FhDUtGTXi3QzcFE2uU1hqtDaKeqrdwj"
REFRESH_TOKEN = "VQapzPI2L1obf62inxuBApzx4cJQj1qFp1Wlm5iWMSs"  # 替换为实际 token


def test_pixiv_login():
    """测试 Pixiv OAuth 登录"""

    # 准备请求体
    data = {
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        "grant_type": "refresh_token",
        "refresh_token": REFRESH_TOKEN,
        "include_policy": "true",
    }

    headers = {
        "Content-Type": "application/x-www-form-urlencoded",
        "User-Agent": "PixivIOSApp/6.7.1 (iOS 14.6; iPhone10,3)",
    }

    print("=" * 60)
    print("Pixiv OAuth 登录测试")
    print("=" * 60)
    print()

    print("[请求信息]")
    print(f"URL: {OAUTH_URL}")
    print(f"Method: POST")
    print(f"Headers: {json.dumps(headers, indent=2)}")
    print()

    # 生成 form-urlencoded 格式的请求体
    form_body = urlencode(data)
    print(f"Body (form-urlencoded):")
    print(form_body)
    print()

    # 发送请求
    print("[正在发送请求...]")
    try:
        response = requests.post(OAUTH_URL, data=data, headers=headers, timeout=10)

        print()
        print("[响应信息]")
        print(f"状态码: {response.status_code}")
        print(
            f"响应头: {json.dumps(dict(response.headers), indent=2, ensure_ascii=False)}"
        )
        print()

        # 尝试解析 JSON 响应
        try:
            response_data = response.json()
            print(f"响应体 (JSON):")
            print(json.dumps(response_data, indent=2, ensure_ascii=False))
        except:
            print(f"响应体 (文本):")
            print(response.text)

        print()
        print("=" * 60)

        if response.status_code == 200:
            print("✓ 登录成功！")
            if "access_token" in response.json():
                print(f"Access Token: {response.json()['access_token'][:20]}...")
        else:
            print(f"✗ 请求失败，状态码: {response.status_code}")
            if "error" in response.json():
                print(f"错误信息: {response.json()['error']}")
                if "error_description" in response.json():
                    print(f"错误描述: {response.json()['error_description']}")

    except requests.exceptions.RequestException as e:
        print(f"请求异常: {e}")

    print("=" * 60)


if __name__ == "__main__":
    test_pixiv_login()
