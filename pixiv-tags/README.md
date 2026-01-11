# Pixiv Tags Collector

一个用于收集 Pixiv 标签的 Python 工具，通过自动补全 API 获取标签信息。

## 功能特性

- ✅ 使用 Pixiv 自动补全 API 收集标签
- ✅ 自动处理认证和 token 刷新
- ✅ **内存缓存**：启动时加载到内存，提高性能
- ✅ **定期自动保存**：每 50 个新标签自动保存到文件
- ✅ **优雅退出**：Ctrl+C 时自动保存内存中的数据
- ✅ **进度恢复**：从中断处继续收集，支持种子词进度跟踪
- ✅ **实时统计**：显示处理速度和预计剩余时间
- ✅ 自动去重，确保标签唯一性
- ✅ 详细的日志记录
- ✅ 错误恢复和备份机制

## 安装依赖

```bash
uv sync
```

## 配置

1. 复制环境变量模板：
```bash
cp .env.example .env
```

2. 编辑 `.env` 文件，填入你的 Pixiv refresh_token：
```
REFRESH_TOKEN=your_refresh_token_here
```

> 获取 refresh_token 的方法请参考 [PixivPy 文档](https://github.com/upbit/pixivpy)

## 运行

### 基本用法

```bash
uv run main.py
```

### 命令行选项

```bash
# 查看当前进度状态
uv run main.py --status

# 重置进度，从头开始收集
uv run main.py --reset

# 正常收集（会自动从中断处继续）
uv run main.py
```

### 安全退出

程序支持优雅退出，按 `Ctrl+C` 可以安全停止：
- 程序会立即停止处理新的请求
- **自动保存内存中的所有标签到文件**
- 显示进度统计信息
- 不会出现 traceback 错误

### 内存管理和自动保存

- **启动时**：自动加载 `data/tags.json` 到内存
- **运行时**：所有新标签先添加到内存，进行去重
- **自动保存**：每收集 50 个新标签自动保存到文件
- **退出时**：确保内存中的所有标签都保存到文件

### 进度管理和中断恢复

- **进度跟踪**：使用 `data/seed_progress.json` 跟踪已处理的种子词
- **中断恢复**：程序中断后，下次运行会自动从中断处继续
- **进度统计**：实时显示处理进度、速度和预计剩余时间
- **优雅退出**：Ctrl+C 时自动保存进度，避免重复处理

这种设计提高了性能，减少了频繁的文件 I/O 操作，同时支持长时间运行的收集任务。

## 输出格式

标签数据保存在 `data/tags.json` 文件中：

```json
{
  "tags": [
    {
      "name": "原神",
      "official_translation": "Genshin Impact",
      "chinese_translation": "",
      "english_translation": ""
    },
    {
      "name": "FGO",
      "official_translation": "",
      "chinese_translation": "",
      "english_translation": ""
    }
  ]
}
```

## 日志文件

程序运行时会生成 `pixiv_tags.log` 日志文件，包含详细的操作记录和错误信息。

## 收集策略

程序使用以下策略收集标签：

1. **种子词生成**：日文假名 + 英文字母 + 数字（约 150+ 个字符）
2. **自动补全 API**：对每个种子词调用 Pixiv 的自动补全接口
3. **去重处理**：确保每个标签名只记录一次
4. **增量保存**：支持程序中断后继续运行

## 翻译获取问题

### 为什么没有获取到官方翻译？

经过对 SwiftUI 项目的深入分析，我们修复了以下问题：

1. **请求头优化**：
   - 使用详细的语言偏好设置：`zh-CN,zh;q=0.9,ja;q=0.8,en;q=0.7`
   - 确保包含完整的 Pixiv 客户端标识信息

2. **API 参数完善**：
   - 使用正确的 v2 版本接口：`/v2/search/autocomplete`
   - 包含 `merge_plain_keyword_results=true` 参数

3. **响应解析**：
   - 正确解析 `translated_name` 字段
   - 添加详细的调试信息

### 调试翻译获取

如果仍然无法获取翻译，可以：

1. **启用调试日志**：
   ```bash
   LOG_LEVEL=DEBUG uv run main.py
   ```

2. **检查语言设置**：
   - 确保请求头包含正确的 `Accept-Language`
   - API 可能对某些关键词不提供翻译

3. **API 限制**：
   - 官方翻译可能只对热门标签提供
   - 某些特定标签可能没有官方翻译

## 故障排除

### 标签没有保存？
检查日志文件 `pixiv_tags.log` 查看是否有错误信息。如果保存失败，程序会创建备份文件 `data/tags.json.new_tags`。

### 认证失败？
确保 `.env` 文件中的 `REFRESH_TOKEN` 是有效的。如果 token 过期，需要重新获取。

### 网络错误？
程序会自动重试失败的请求。如果持续失败，检查网络连接或代理设置。