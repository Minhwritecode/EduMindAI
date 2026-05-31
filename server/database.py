import os
from motor.motor_asyncio import AsyncIOMotorClient
from dotenv import load_dotenv

load_dotenv()

MONGO_URI = os.getenv("MONGO_URI", "").strip()

client = None
db = None

async def connect_to_mongo():
    global client, db
    if MONGO_URI:
        try:
            client = AsyncIOMotorClient(MONGO_URI, serverSelectionTimeoutMS=8000)
            db = client["pm_edu_mind"]
            await db.command("ping")
            print("Connected to MongoDB successfully!")
        except Exception as e:
            print(f"MongoDB connection failed: {e}")
            client = None
            db = None
    else:
        print("MONGO_URI not found in environment.")

async def close_mongo_connection():
    global client
    if client:
        client.close()
        print("MongoDB connection closed.")
