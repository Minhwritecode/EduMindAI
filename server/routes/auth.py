from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from passlib.context import CryptContext
import jwt
from datetime import datetime, timedelta, timezone
import uuid
import os

import server.database as database

router = APIRouter(prefix="/api/auth", tags=["auth"])

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
SECRET_KEY = os.getenv("JWT_SECRET", "super-secret-key-change-in-production")
ALGORITHM = "HS256"

class RegisterRequest(BaseModel):
    username: str
    email: str
    password: str
    fieldOfInterest: str = ""

class LoginRequest(BaseModel):
    username: str
    password: str

class AuthResponse(BaseModel):
    ok: bool
    token: str = ""
    userId: str = ""
    error: str = ""

def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(days=30)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

@router.post("/register", response_model=AuthResponse)
async def register_user(request: RegisterRequest):
    if database.db is None:
        raise HTTPException(status_code=503, detail="MongoDB not configured")
    
    # Check if user already exists
    existing = await database.db["users"].find_one({"username": request.username})
    if existing:
        return AuthResponse(ok=False, error="Username already exists")
    
    existing_email = await database.db["users"].find_one({"email": request.email})
    if existing_email:
        return AuthResponse(ok=False, error="Email already in use")

    hashed_password = pwd_context.hash(request.password)
    user_id = str(uuid.uuid4())

    user_data = {
        "userId": user_id,
        "username": request.username,
        "email": request.email,
        "password": hashed_password,
        "fieldOfInterest": request.fieldOfInterest,
        "createdAt": datetime.now(timezone.utc)
    }

    await database.db["users"].insert_one(user_data)

    token = create_access_token({"sub": user_id, "username": request.username})
    return AuthResponse(ok=True, token=token, userId=user_id)

@router.post("/login", response_model=AuthResponse)
async def login_user(request: LoginRequest):
    if database.db is None:
        raise HTTPException(status_code=503, detail="MongoDB not configured")
    
    user = await database.db["users"].find_one({"username": request.username})
    if not user:
        return AuthResponse(ok=False, error="Invalid username or password")
    
    if not pwd_context.verify(request.password, user["password"]):
        return AuthResponse(ok=False, error="Invalid username or password")
    
    token = create_access_token({"sub": user["userId"], "username": request.username})
    return AuthResponse(ok=True, token=token, userId=user["userId"])
