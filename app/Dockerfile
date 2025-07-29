# 1. ベースとなる公式Pythonイメージを選択
FROM python:3.11-slim

# 2. 作業ディレクトリを設定
WORKDIR /app

# 3. 必要なファイルをコンテナにコピー
COPY requirements.txt .
COPY rag_app.py .
COPY documents/ ./documents/
COPY chroma_db/ ./chroma_db/

# 4. 依存ライブラリをインストール
RUN pip install --no-cache-dir -r requirements.txt

# 5. APIサーバーが使用するポートを公開
EXPOSE 8000

# 6. コンテナ起動時に実行するコマンド
CMD ["uvicorn", "rag_app:app", "--host", "0.0.0.0", "--port", "8000"]