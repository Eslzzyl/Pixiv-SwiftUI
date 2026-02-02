#!/usr/bin/env python3
import os
import logging
from typing import Optional
from pathlib import Path

from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

from dotenv import load_dotenv

from src.sqlite_storage import SQLiteStorage

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

app = FastAPI(title="Pixiv Tag Review WebUI")

BASE_DIR = Path(__file__).resolve().parent.parent
DB_PATH = os.getenv("SQLITE_DB_PATH", str(BASE_DIR / "data" / "pixiv_tags.db"))

storage = SQLiteStorage(DB_PATH)
storage.init()

templates = Jinja2Templates(directory=str(Path(__file__).parent / "templates"))

app.mount(
    "/static",
    StaticFiles(directory=str(Path(__file__).parent / "static")),
    name="static",
)


@app.get("/", response_class=HTMLResponse)
async def index(request: Request, index: Optional[int] = 0, language: str = "chinese"):
    """主页面"""
    if language not in ["chinese", "english"]:
        language = "chinese"

    stats = storage.get_review_count(language)
    tag = storage.get_tag_by_index(index, language)

    context = {
        "request": request,
        "index": index,
        "language": language,
        "stats": stats,
        "tag": tag,
    }

    return templates.TemplateResponse("index.html", context)


@app.get("/api/tag/current")
async def get_current_tag(index: int = 0, language: str = "chinese"):
    """获取当前标签"""
    if language not in ["chinese", "english"]:
        language = "chinese"

    tag = storage.get_tag_by_index(index, language)

    if not tag:
        raise HTTPException(status_code=404, detail="Tag not found")

    return JSONResponse(content=tag.to_dict())


@app.get("/api/tag/next")
async def get_next_tag(current_index: int = 0, language: str = "chinese"):
    """获取下一个标签"""
    if language not in ["chinese", "english"]:
        language = "chinese"

    next_index = current_index + 1
    tag = storage.get_tag_by_index(next_index, language)

    if not tag:
        raise HTTPException(status_code=404, detail="No more tags")

    return JSONResponse(content={"index": next_index, **tag.to_dict()})


@app.get("/api/tag/prev")
async def get_prev_tag(current_index: int = 0, language: str = "chinese"):
    """获取上一个标签"""
    if language not in ["chinese", "english"]:
        language = "chinese"

    prev_index = max(0, current_index - 1)
    tag = storage.get_tag_by_index(prev_index, language)

    return JSONResponse(content={"index": prev_index, **tag.to_dict()})


@app.get("/api/tag/next-unreviewed")
async def get_next_unreviewed(current_tag_name: str, language: str = "chinese"):
    """获取下一个未审核标签"""
    if language not in ["chinese", "english"]:
        language = "chinese"

    tag = storage.get_next_unreviewed(current_tag_name, language)

    if not tag:
        raise HTTPException(status_code=404, detail="No more unreviewed tags")

    return JSONResponse(content=tag.to_dict())


@app.get("/api/tag/prev-unreviewed")
async def get_prev_unreviewed(current_tag_name: str, language: str = "chinese"):
    """获取上一个未审核标签"""
    if language not in ["chinese", "english"]:
        language = "chinese"

    tag = storage.get_prev_unreviewed(current_tag_name, language)

    if not tag:
        return JSONResponse(content=None)

    return JSONResponse(content=tag.to_dict())


@app.post("/api/tag/update")
async def update_tag(request: Request):
    """更新标签翻译"""
    data = await request.json()

    name = data.get("name")
    language = data.get("language", "chinese")

    if not name:
        raise HTTPException(status_code=400, detail="name is required")

    update_params = {}
    if language == "chinese":
        update_params["chinese_reviewed"] = data.get("reviewed")
        if "translation" in data:
            update_params["chinese_translation"] = data["translation"]
    elif language == "english":
        update_params["english_reviewed"] = data.get("reviewed")
        if "translation" in data:
            update_params["english_translation"] = data["translation"]

    success = storage.update_translation_and_review(name, **update_params)

    if not success:
        raise HTTPException(status_code=404, detail="Tag not found or update failed")

    return JSONResponse(content={"success": True})


@app.get("/api/stats")
async def get_stats(language: str = "chinese"):
    """获取审核统计"""
    if language not in ["chinese", "english"]:
        language = "chinese"

    stats = storage.get_review_count(language)
    return JSONResponse(content=stats)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=5000, log_level="info")
