"""
MIT License

Copyright (c) 2025 Eslzzyl

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

https://github.com/Eslzzyl/llm-client
"""

import base64
import json
import mimetypes
import os
from pathlib import Path
from typing import Any, Dict, Iterator, List, Optional, Union

import httpx
from pydantic import BaseModel


class ImageContent(BaseModel):
    """图片内容，支持从路径读取或直接传入bytes"""

    type: str = "image_url"
    image_url: Dict[str, str]

    @classmethod
    def from_path(cls, path: Union[str, Path]) -> "ImageContent":
        """从文件路径创建图片内容"""
        path = Path(path)
        if not path.exists():
            raise FileNotFoundError(f"图片文件不存在: {path}")

        with open(path, "rb") as f:
            image_bytes = f.read()

        # 猜测MIME类型
        mime_type = mimetypes.guess_type(path.as_posix())[0] or "image/jpeg"

        # 编码为base64
        base64_image = base64.b64encode(image_bytes).decode("utf-8")
        data_url = f"data:{mime_type};base64,{base64_image}"

        return cls(image_url={"url": data_url})

    @classmethod
    def from_bytes(
        cls, image_bytes: bytes, mime_type: str = "image/jpeg"
    ) -> "ImageContent":
        """从bytes创建图片内容"""
        base64_image = base64.b64encode(image_bytes).decode("utf-8")
        data_url = f"data:{mime_type};base64,{base64_image}"

        return cls(image_url={"url": data_url})


class TextContent(BaseModel):
    """文本内容"""

    type: str = "text"
    text: str


class Message(BaseModel):
    """消息模型"""

    role: str  # "user", "assistant", "system", "tool"
    content: Union[str, List[Union[TextContent, ImageContent]]]

    @classmethod
    def user_text(cls, text: str) -> "Message":
        """创建用户文本消息"""
        return cls(role="user", content=text)

    @classmethod
    def user_multimodal(
        cls, text: str, images: List[Union[str, Path, bytes, ImageContent]] = None
    ) -> "Message":
        """创建用户多模态消息（文本+图片）"""
        content = [TextContent(text=text)]

        if images:
            for image in images:
                if isinstance(image, ImageContent):
                    content.append(image)
                elif isinstance(image, bytes):
                    content.append(ImageContent.from_bytes(image))
                else:
                    content.append(ImageContent.from_path(image))

        return cls(role="user", content=content)

    @classmethod
    def assistant(cls, text: str) -> "Message":
        """创建助手消息"""
        return cls(role="assistant", content=text)

    @classmethod
    def system(cls, text: str) -> "Message":
        """创建系统消息"""
        return cls(role="system", content=text)

    @classmethod
    def tool(cls, text: str) -> "Message":
        """创建工具消息"""
        return cls(role="tool", content=text)


class Usage(BaseModel):
    """使用统计"""

    prompt_tokens: int = 0
    completion_tokens: int = 0
    total_tokens: int = 0


class Choice(BaseModel):
    """选择项"""

    index: int
    message: Message
    finish_reason: Optional[str] = None


class StreamChoice(BaseModel):
    """流式选择项"""

    index: int
    delta: Dict[str, Any]
    finish_reason: Optional[str] = None


class ChatCompletion(BaseModel):
    """聊天完成响应"""

    id: str
    object: str = "chat.completion"
    created: int
    model: str
    choices: List[Choice]
    usage: Usage

    @property
    def content(self) -> str:
        """获取主要回复内容"""
        if self.choices:
            return self.choices[0].message.content
        return ""

    @property
    def input_tokens(self) -> int:
        """输入token数量"""
        return self.usage.prompt_tokens

    @property
    def output_tokens(self) -> int:
        """输出token数量"""
        return self.usage.completion_tokens

    @property
    def total_tokens(self) -> int:
        """总token数量"""
        return self.usage.total_tokens


class StreamChunk(BaseModel):
    """流式响应块"""

    id: str
    object: str = "chat.completion.chunk"
    created: int
    model: str
    choices: List[StreamChoice]
    usage: Optional[Usage] = None

    @property
    def content(self) -> str:
        """获取增量内容"""
        if self.choices and "content" in self.choices[0].delta:
            return self.choices[0].delta["content"] or ""
        return ""

    @property
    def is_finished(self) -> bool:
        """是否已完成"""
        return any(choice.finish_reason is not None for choice in self.choices)


class LLMClient:
    """OpenAI兼容API的LLM客户端"""

    def __init__(
        self,
        api_key: Optional[str] = None,
        base_url: Optional[str] = None,
        model: str = "gpt-4o-mini",
        timeout: float = 60.0,
    ):
        """
        初始化LLM客户端

        Args:
            api_key: API密钥，如果不提供则从环境变量OPENAI_API_KEY读取
            base_url: API基础URL，如果不提供则从环境变量OPENAI_BASE_URL读取，默认为OpenAI官方API
            model: 默认使用的模型名称
            timeout: 请求超时时间（秒）
        """
        self.api_key = api_key or os.getenv("OPENAI_API_KEY")
        self.base_url = (
            base_url or os.getenv("OPENAI_BASE_URL") or "https://api.openai.com/v1"
        ).rstrip("/")
        self.model = model
        self.timeout = timeout

        if not self.api_key:
            raise ValueError(
                "API密钥未提供。请通过参数传入或设置环境变量OPENAI_API_KEY"
            )

        # 创建HTTP客户端
        self.client = httpx.Client(
            timeout=timeout,
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            },
        )

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.client.close()

    def chat(
        self,
        messages: List[Message],
        system_prompt: Optional[str] = None,
        model: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: Optional[int] = None,
        stream: bool = False,
        response_format: Optional[Dict[str, Any]] = None,
        **kwargs,
    ) -> Union[ChatCompletion, Iterator[StreamChunk]]:
        """
        发送聊天请求

        Args:
            messages: 消息列表
            system_prompt: 可选的系统提示
            model: 使用的模型，如果不指定则使用默认模型
            temperature: 温度参数，控制回复的随机性
            max_tokens: 最大token数量
            stream: 是否使用流式响应
            response_format: 可选的响应格式字典，会原样序列化到请求中
            **kwargs: 其他API参数

        Returns:
            ChatCompletion或StreamChunk的迭代器
        """
        # 准备消息列表
        final_messages = []

        # 添加系统消息（如果提供）
        if system_prompt:
            final_messages.append(Message.system(system_prompt).model_dump())

        # 添加用户消息
        for msg in messages:
            final_messages.append(msg.model_dump())

        # 准备请求数据
        data = {
            "model": model or self.model,
            "messages": final_messages,
            "temperature": temperature,
            "stream": stream,
            **kwargs,
        }

        if response_format is not None:
            data["response_format"] = response_format

        if max_tokens is not None:
            data["max_tokens"] = max_tokens

        # 发送请求
        url = f"{self.base_url}/chat/completions"

        if stream:
            return self._stream_request(url, data)
        else:
            return self._sync_request(url, data)

    def _sync_request(self, url: str, data: Dict[str, Any]) -> ChatCompletion:
        """发送同步请求"""
        response = self.client.post(url, json=data)
        response.raise_for_status()

        result = response.json()
        return ChatCompletion(**result)

    def _stream_request(self, url: str, data: Dict[str, Any]) -> Iterator[StreamChunk]:
        """发送流式请求"""
        with self.client.stream("POST", url, json=data) as response:
            response.raise_for_status()

            for line in response.iter_lines():
                if not line.strip():
                    continue

                if line.startswith("data: "):
                    data_str = line[6:]  # 移除 "data: " 前缀

                    if data_str.strip() == "[DONE]":
                        break

                    try:
                        chunk_data = json.loads(data_str)
                        yield StreamChunk(**chunk_data)
                    except json.JSONDecodeError:
                        continue

    def simple_chat(
        self,
        text: str,
        system_prompt: Optional[str] = None,
        images: Optional[List[Union[str, Path, bytes]]] = None,
        temperature: float = 0.7,
        max_tokens: Optional[int] = None,
        response_format: Optional[Dict[str, Any]] = None,
        **kwargs,
    ) -> ChatCompletion:
        """
        简单聊天接口

        Args:
            text: 用户输入的文本
            system_prompt: 可选的系统提示
            images: 可选的图片列表（路径、Path对象或bytes）
            response_format: 可选的响应格式字典，会原样序列化到请求中
            **kwargs: 其他聊天参数

        Returns:
            模型的回复内容
        """
        if images:
            message = Message.user_multimodal(text, images)
        else:
            message = Message.user_text(text)

        return self.chat(
            [message],
            system_prompt=system_prompt,
            response_format=response_format,
            temperature=temperature,
            max_tokens=max_tokens,
            **kwargs,
        )

    def simple_chat_stream(
        self,
        text: str,
        system_prompt: Optional[str] = None,
        images: Optional[List[Union[str, Path, bytes]]] = None,
        temperature: float = 0.7,
        max_tokens: Optional[int] = None,
        response_format: Optional[Dict[str, Any]] = None,
        **kwargs,
    ) -> Iterator[StreamChunk]:
        """
        简单流式聊天接口

        Args:
            text: 用户输入的文本
            system_prompt: 可选的系统提示
            images: 可选的图片列表（路径、Path对象或bytes）
            response_format: 可选的响应格式字典，会原样序列化到请求中
            **kwargs: 其他聊天参数

        Returns:
            StreamChunk的迭代器
        """
        if images:
            message = Message.user_multimodal(text, images)
        else:
            message = Message.user_text(text)

        return self.chat(
            [message],
            system_prompt=system_prompt,
            stream=True,
            response_format=response_format,
            temperature=temperature,
            max_tokens=max_tokens,
            **kwargs,
        )
