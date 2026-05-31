from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime, timezone
import uuid

import server.database as database

router = APIRouter(prefix="/api/schedules", tags=["schedules"])

class TimeSlot(BaseModel):
    start_time: str
    end_time: str
    subject: str
    room_or_link: Optional[str] = ""
    notebook_id: Optional[str] = ""

class TimetableDay(BaseModel):
    day_of_week: str
    slots: List[TimeSlot] = []

class TodoTask(BaseModel):
    task_id: Optional[str] = ""
    title: str
    due_date: Optional[str] = None  # ISO format string
    is_completed: bool = False
    notebook_id: Optional[str] = ""

class ScheduleResponse(BaseModel):
    user_id: str
    timetable: List[TimetableDay]
    todo_list: List[TodoTask]

@router.get("", response_model=ScheduleResponse)
async def get_schedule(userId: str):
    if database.db is None:
        raise HTTPException(status_code=503, detail="MongoDB not configured")
    
    doc = await database.db["schedules"].find_one({"user_id": userId})
    if not doc:
        # Create an empty template
        doc = {
            "user_id": userId,
            "timetable": [
                {"day_of_week": day, "slots": []}
                for day in ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
            ],
            "todo_list": []
        }
        await database.db["schedules"].insert_one(doc)
    
    return ScheduleResponse(
        user_id=doc.get("user_id"),
        timetable=doc.get("timetable", []),
        todo_list=doc.get("todo_list", [])
    )

@router.post("/timetable", response_model=dict)
async def update_timetable(userId: str, timetable: List[TimetableDay]):
    if database.db is None:
        raise HTTPException(status_code=503, detail="MongoDB not configured")
    
    # Save the complete timetable for the user
    await database.db["schedules"].update_one(
        {"user_id": userId},
        {"$set": {"timetable": [day.model_dump() for day in timetable]}},
        upsert=True
    )
    return {"ok": True}

@router.post("/todo", response_model=dict)
async def add_or_update_todo(userId: str, task: TodoTask):
    if database.db is None:
        raise HTTPException(status_code=503, detail="MongoDB not configured")
    
    task_id = task.task_id
    if not task_id:
        task_id = str(uuid.uuid4())
    
    task_data = task.model_dump()
    task_data["task_id"] = task_id
    
    # Check if schedule exists
    doc = await database.db["schedules"].find_one({"user_id": userId})
    if not doc:
        # Create schedule document with this single task
        await database.db["schedules"].insert_one({
            "user_id": userId,
            "timetable": [
                {"day_of_week": day, "slots": []}
                for day in ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
            ],
            "todo_list": [task_data]
        })
    else:
        # Find if task exists to update, else append
        todo_list = doc.get("todo_list", [])
        existing_index = next((i for i, t in enumerate(todo_list) if t.get("task_id") == task_id), -1)
        
        if existing_index >= 0:
            todo_list[existing_index] = task_data
        else:
            todo_list.append(task_data)
            
        await database.db["schedules"].update_one(
            {"user_id": userId},
            {"$set": {"todo_list": todo_list}}
        )
        
    return {"ok": True, "task_id": task_id}

@router.delete("/todo/{task_id}", response_model=dict)
async def delete_todo(userId: str, task_id: str):
    if database.db is None:
        raise HTTPException(status_code=503, detail="MongoDB not configured")
    
    doc = await database.db["schedules"].find_one({"user_id": userId})
    if not doc:
        raise HTTPException(status_code=404, detail="Schedule not found")
        
    todo_list = doc.get("todo_list", [])
    filtered_list = [t for t in todo_list if t.get("task_id") != task_id]
    
    if len(todo_list) == len(filtered_list):
        raise HTTPException(status_code=404, detail="Task not found")
        
    await database.db["schedules"].update_one(
        {"user_id": userId},
        {"$set": {"todo_list": filtered_list}}
    )
    return {"ok": True}
