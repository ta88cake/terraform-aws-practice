from fastapi import FastAPI
from pydantic import BaseModel
from langchain_community.vectorstores import Chroma
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_community.llms import Ollama
from langchain.prompts import PromptTemplate
from langchain.chains import RetrievalQA

# --- ステップ1: AIの準備（起動時に一度だけ実行） ---

# 1. テキストをベクトルに変換するAI（埋め込みモデル）を準備
embeddings = HuggingFaceEmbeddings(
    model_name="intfloat/multilingual-e5-large-instruct"
)

# 2. 構築済みのデータベースを読み込む
db = Chroma(persist_directory="./chroma_db", embedding_function=embeddings)

# 3. 回答を生成するAI（OllamaのLlama3）を準備
llm = Ollama(model="phi3", base_url="http://localhost:11434")

# 4. AIに与える指示書（プロンプトテンプレート）を作成
# 【修正前】
# prompt_template = """
# 以下の「コンテキスト」だけを使って、質問に答えてください。
# コンテキストに答えがない場合は、「分かりません」と答えてください。
# ...
# """

# 【修正後】
prompt_template = """
あなたは、親切で優秀な英語学習アシスタントです。
提供された「コンテキスト」の情報を元に、簡潔で分かりやすく質問に答えてください。
コンテキストから答えが見つからない場合は、正直に「その単語の情報は見つかりませんでした」と回答してください。
コンテキストの内容を、そのままオウム返ししてはいけません。

コンテキスト:
{context}

質問:
{question}

回答:
"""
prompt = PromptTemplate(
    template=prompt_template, input_variables=["context", "question"]
)

# 5. RAGの仕組み（チェーン）を構築
qa_chain = RetrievalQA.from_chain_type(
    llm=llm,
    chain_type="stuff",
    retriever=db.as_retriever(),
    chain_type_kwargs={"prompt": prompt},
    return_source_documents=True,
)


# --- ステップ2: FastAPIアプリの定義 ---

# 6. FastAPIアプリを初期化
app = FastAPI()

# 7. リクエストの型を定義（質問文を受け取るためのモデル）
class QuestionRequest(BaseModel):
    query: str

# 8. APIエンドポイントの定義
@app.post("/ask")
def ask_question(request: QuestionRequest):
    # 受け取った質問文でAIを実行
    result = qa_chain.invoke({"query": request.query})
    # 結果を返す
    return {"answer": result["result"], "source_documents": result["source_documents"]}
