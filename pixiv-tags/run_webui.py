#!/usr/bin/env python3
import os
import sys

import uvicorn

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE_DIR)

if __name__ == "__main__":
    uvicorn.run(
        "webui.app:app", host="127.0.0.1", port=26202, reload=False, log_level="info"
    )
