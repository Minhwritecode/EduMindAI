from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from server.database import connect_to_mongo, close_mongo_connection, db
from server.routes import notebook, auth, schedule, chat

@asynccontextmanager
async def lifespan(app: FastAPI):
    await connect_to_mongo()
    yield
    await close_mongo_connection()

app = FastAPI(title="EduMind Backend API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(notebook.router)
app.include_router(auth.router)
app.include_router(schedule.router)
app.include_router(chat.router)

@app.get("/health", tags=["health"])
async def health_check():
    return {
        "ok": True,
        "mongo": db is not None,
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("server.main:app", host="0.0.0.0", port=8000, reload=True)
