from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime, timezone
import uuid
import os
import google.generativeai as genai

import server.database as database

router = APIRouter(prefix="/api/notebooks", tags=["chat"])

api_key = os.getenv("GEMINI_API_KEY", "").strip()
if api_key:
    genai.configure(api_key=api_key)

class MessageItem(BaseModel):
    sender: str  # "user" or "ai"
    message_text: str
    timestamp: Optional[str] = None

class ChatHistoryResponse(BaseModel):
    notebook_id: str
    messages: List[MessageItem]

class ChatRequest(BaseModel):
    userId: str
    message_text: str

@router.get("/{notebook_id}/chat", response_model=ChatHistoryResponse)
async def get_chat_history(notebook_id: str):
    if database.db is None:
        raise HTTPException(status_code=503, detail="MongoDB not configured")
        
    doc = await database.db["chat_histories"].find_one({"notebook_id": notebook_id})
    if not doc:
        return ChatHistoryResponse(notebook_id=notebook_id, messages=[])
        
    messages = []
    for msg in doc.get("messages", []):
        ts = msg.get("timestamp")
        if isinstance(ts, datetime):
            ts = ts.isoformat()
        messages.append(MessageItem(
            sender=msg.get("sender"),
            message_text=msg.get("message_text"),
            timestamp=ts
        ))
        
    return ChatHistoryResponse(notebook_id=notebook_id, messages=messages)

@router.post("/{notebook_id}/chat", response_model=dict)
async def send_chat_message(notebook_id: str, payload: ChatRequest):
    if not api_key:
        raise HTTPException(status_code=500, detail="Gemini API Key not configured")
    if database.db is None:
        raise HTTPException(status_code=503, detail="MongoDB not configured")
        
    # 1. Fetch Notebook Sources context
    notebook = await database.db["notebooks"].find_one({"userId": payload.userId, "id": notebook_id})
    if not notebook:
        raise HTTPException(status_code=404, detail="Notebook not found")
        
    sources = notebook.get("sources", [])
    context_text = "\n\n".join([s.get("content", "") for s in sources])
    if not context_text:
        context_text = notebook.get("text", "") # Fallback legacy text
        
    # 2. Fetch Chat History
    chat_doc = await database.db["chat_histories"].find_one({"notebook_id": notebook_id})
    if not chat_doc:
        chat_doc = {"notebook_id": notebook_id, "messages": []}
        
    history = chat_doc.get("messages", [])
    
    # 3. Format the Prompt for Gemini with RAG
    prompt_buffer = []
    prompt_buffer.append("You are an AI Tutor helper. Help the student study the provided documents. Answer concisely in Vietnamese.")
    if context_text.strip():
        prompt_buffer.append(f"Here is the study material context:\n\"\"\"\n{context_text.strip()}\n\"\"\"\n")
    else:
        prompt_buffer.append("No study materials have been uploaded to this notebook yet. Answer general questions as best as you can.")
        
    prompt_buffer.append("Conversation history:")
    # Append last 15 messages for context
    for msg in history[-15:]:
        sender_label = "Student" if msg.get("sender") == "user" else "AI Tutor"
        prompt_buffer.append(f"{sender_label}: {msg.get('message_text')}")
        
    prompt_buffer.append(f"Student: {payload.message_text}")
    prompt_buffer.append("AI Tutor:")
    
    full_prompt = "\n".join(prompt_buffer)
    
    try:
        model = genai.GenerativeModel("gemini-flash-latest")
        response = model.generate_content(full_prompt)
        ai_response = response.text.strip()
        
        # 4. Save messages to history
        now = datetime.now(timezone.utc)
        user_msg = {
            "sender": "user",
            "message_text": payload.message_text,
            "timestamp": now
        }
        ai_msg = {
            "sender": "ai",
            "message_text": ai_response,
            "timestamp": now
        }
        
        history.append(user_msg)
        history.append(ai_msg)
        
        await database.db["chat_histories"].update_one(
            {"notebook_id": notebook_id},
            {"$set": {"messages": history}},
            upsert=True
        )
        
        return {"ok": True, "ai_response": ai_response}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI Chat failed: {str(e)}")
