# app/rag_app.py （デバッグ用シンプル版）

from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def read_root():
    return {"message": "CI/CD pipeline test successful!"}