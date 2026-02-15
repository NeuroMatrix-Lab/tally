from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime, timedelta
import sqlite3
import json
from contextlib import contextmanager
import os
import uuid
import shutil

app = FastAPI(title="Tally Server", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

DATABASE_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "tally.db")
UPLOAD_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")


@contextmanager
def get_db():
    os.makedirs(os.path.dirname(DATABASE_FILE), exist_ok=True)
    conn = sqlite3.connect(DATABASE_FILE)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
    finally:
        conn.close()


def init_db():
    os.makedirs(os.path.dirname(DATABASE_FILE), exist_ok=True)
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                record_id TEXT UNIQUE NOT NULL,
                date TEXT NOT NULL,
                category TEXT NOT NULL,
                work_content TEXT NOT NULL,
                amount REAL NOT NULL,
                ledger TEXT NOT NULL,
                image_url TEXT,
                created_at TEXT,
                updated_at TEXT
            )
        ''')
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS deleted_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                record_id TEXT UNIQUE NOT NULL,
                date TEXT NOT NULL,
                category TEXT NOT NULL,
                work_content TEXT NOT NULL,
                amount REAL NOT NULL,
                ledger TEXT NOT NULL,
                image_url TEXT,
                deleted_at TEXT
            )
        ''')
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS ledgers (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT UNIQUE NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT
            )
        ''')
        
        cursor.execute("PRAGMA table_info(records)")
        columns = [column[1] for column in cursor.fetchall()]
        if 'image_url' not in columns:
            cursor.execute('ALTER TABLE records ADD COLUMN image_url TEXT')
        
        cursor.execute("PRAGMA table_info(deleted_records)")
        columns = [column[1] for column in cursor.fetchall()]
        if 'image_url' not in columns:
            cursor.execute('ALTER TABLE deleted_records ADD COLUMN image_url TEXT')
        
        conn.commit()


class RecordDTO(BaseModel):
    recordId: str
    date: datetime
    category: str
    workContent: str
    amount: float
    ledger: str
    imageUrl: Optional[str] = None


class LedgerDTO(BaseModel):
    name: str


@app.on_event("startup")
async def startup_event():
    init_db()


@app.get("/api/records/recent")
async def get_recent_records(months: int = 3):
    start_date = datetime.now() - timedelta(days=months * 30)
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            SELECT record_id, date, category, work_content, amount, ledger, image_url
            FROM records
            WHERE date >= ?
            ORDER BY date DESC
        ''', (start_date.isoformat(),))
        rows = cursor.fetchall()
    
    return [
        {
            "recordId": row["record_id"],
            "date": row["date"],
            "category": row["category"],
            "workContent": row["work_content"],
            "amount": row["amount"],
            "ledger": row["ledger"],
            "imageUrl": row["image_url"],
        }
        for row in rows
    ]


@app.get("/api/records/search")
async def search_records(
    startDate: datetime,
    endDate: datetime,
    category: Optional[str] = None,
    ledger: Optional[str] = None
):
    with get_db() as conn:
        cursor = conn.cursor()
        
        query = '''
            SELECT record_id, date, category, work_content, amount, ledger, image_url
            FROM records
            WHERE date >= ? AND date <= ?
        '''
        params = [startDate.isoformat(), endDate.isoformat()]
        
        if category:
            query += ' AND category = ?'
            params.append(category)
        
        if ledger:
            query += ' AND ledger = ?'
            params.append(ledger)
        
        query += ' ORDER BY date DESC'
        
        cursor.execute(query, params)
        rows = cursor.fetchall()
    
    return [
        {
            "recordId": row["record_id"],
            "date": row["date"],
            "category": row["category"],
            "workContent": row["work_content"],
            "amount": row["amount"],
            "ledger": row["ledger"],
            "imageUrl": row["image_url"],
        }
        for row in rows
    ]


@app.get("/api/records/categories")
async def get_recent_categories(months: int = 3):
    start_date = datetime.now() - timedelta(days=months * 30)
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            SELECT DISTINCT category
            FROM records
            WHERE date >= ?
            ORDER BY category
        ''', (start_date.isoformat(),))
        rows = cursor.fetchall()
    
    return [row["category"] for row in rows]


@app.get("/api/records/work-contents")
async def get_recent_work_contents(months: int = 3):
    start_date = datetime.now() - timedelta(days=months * 30)
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            SELECT DISTINCT work_content
            FROM records
            WHERE date >= ?
            ORDER BY work_content
        ''', (start_date.isoformat(),))
        rows = cursor.fetchall()
    
    return [row["work_content"] for row in rows]


@app.post("/api/upload")
async def upload_image(file: UploadFile = File(...)):
    file_extension = file.filename.split('.')[-1].lower()
    if file_extension not in ['jpg', 'jpeg', 'png', 'gif', 'webp']:
        raise HTTPException(status_code=400, detail="Invalid file type")
    
    unique_filename = f"{uuid.uuid4()}.{file_extension}"
    file_path = os.path.join(UPLOAD_DIR, unique_filename)
    
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    
    return {"imageUrl": f"/uploads/{unique_filename}"}


@app.post("/api/records")
async def create_record(record: RecordDTO):
    try:
        with get_db() as conn:
            cursor = conn.cursor()
            now = datetime.now().isoformat()
            cursor.execute('''
                INSERT INTO records (record_id, date, category, work_content, amount, ledger, image_url, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                record.recordId,
                record.date.isoformat(),
                record.category,
                record.workContent,
                record.amount,
                record.ledger,
                record.imageUrl,
                now,
                now
            ))
            conn.commit()
        
        return {
            "recordId": record.recordId,
            "date": record.date.isoformat(),
            "category": record.category,
            "workContent": record.workContent,
            "amount": record.amount,
            "ledger": record.ledger,
            "imageUrl": record.imageUrl,
        }
    except sqlite3.IntegrityError:
        raise HTTPException(status_code=400, detail="Record ID already exists")


@app.put("/api/records/{record_id}")
async def update_record(record_id: str, record: RecordDTO):
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            UPDATE records
            SET date = ?, category = ?, work_content = ?, amount = ?, ledger = ?, image_url = ?, updated_at = ?
            WHERE record_id = ?
        ''', (
            record.date.isoformat(),
            record.category,
            record.workContent,
            record.amount,
            record.ledger,
            record.imageUrl,
            datetime.now().isoformat(),
            record_id
        ))
        conn.commit()
        
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Record not found")
    
    return {
        "recordId": record.recordId,
        "date": record.date.isoformat(),
        "category": record.category,
        "workContent": record.workContent,
        "amount": record.amount,
        "ledger": record.ledger,
        "imageUrl": record.imageUrl,
    }


@app.delete("/api/records/{record_id}")
async def delete_record(record_id: str):
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute('SELECT record_id, date, category, work_content, amount, ledger, image_url FROM records WHERE record_id = ?', (record_id,))
        row = cursor.fetchone()
        
        if row is None:
            raise HTTPException(status_code=404, detail="Record not found")
        
        deleted_record = {
            "recordId": row["record_id"],
            "date": row["date"],
            "category": row["category"],
            "workContent": row["work_content"],
            "amount": row["amount"],
            "ledger": row["ledger"],
            "imageUrl": row["image_url"],
        }
        
        cursor.execute('DELETE FROM records WHERE record_id = ?', (record_id,))
        
        cursor.execute('''
            INSERT INTO deleted_records (record_id, date, category, work_content, amount, ledger, image_url, deleted_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            deleted_record["recordId"],
            deleted_record["date"],
            deleted_record["category"],
            deleted_record["workContent"],
            deleted_record["amount"],
            deleted_record["ledger"],
            deleted_record["imageUrl"],
            datetime.now().isoformat()
        ))
        
        cursor.execute('''
            DELETE FROM deleted_records 
            WHERE id NOT IN (
                SELECT id FROM deleted_records ORDER BY deleted_at DESC LIMIT 300
            )
        ''')
        
        conn.commit()
    
    return {"message": "Record deleted successfully"}


@app.get("/api/deleted-records")
async def get_deleted_records():
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            SELECT record_id, date, category, work_content, amount, ledger, image_url, deleted_at
            FROM deleted_records
            ORDER BY deleted_at DESC
        ''')
        rows = cursor.fetchall()
    
    return [
        {
            "recordId": row["record_id"],
            "date": row["date"],
            "category": row["category"],
            "workContent": row["work_content"],
            "amount": row["amount"],
            "ledger": row["ledger"],
            "imageUrl": row["image_url"],
            "deletedAt": row["deleted_at"],
        }
        for row in rows
    ]


@app.post("/api/deleted-records/{record_id}/restore")
async def restore_deleted_record(record_id: str):
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            SELECT record_id, date, category, work_content, amount, ledger, image_url 
            FROM deleted_records 
            WHERE record_id = ?
        ''', (record_id,))
        row = cursor.fetchone()
        
        if row is None:
            raise HTTPException(status_code=404, detail="Deleted record not found")
        
        restored_record = {
            "recordId": row["record_id"],
            "date": row["date"],
            "category": row["category"],
            "workContent": row["work_content"],
            "amount": row["amount"],
            "ledger": row["ledger"],
            "imageUrl": row["image_url"],
        }
        
        now = datetime.now().isoformat()
        cursor.execute('''
            INSERT INTO records (record_id, date, category, work_content, amount, ledger, image_url, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            restored_record["recordId"],
            restored_record["date"],
            restored_record["category"],
            restored_record["workContent"],
            restored_record["amount"],
            restored_record["ledger"],
            restored_record["imageUrl"],
            now,
            now
        ))
        
        cursor.execute('DELETE FROM deleted_records WHERE record_id = ?', (record_id,))
        conn.commit()
    
    return {
        "recordId": restored_record["recordId"],
        "date": restored_record["date"],
        "category": restored_record["category"],
        "workContent": restored_record["workContent"],
        "amount": restored_record["amount"],
        "ledger": restored_record["ledger"],
        "imageUrl": restored_record["imageUrl"],
    }


@app.delete("/api/deleted-records/{record_id}")
async def permanently_delete_record(record_id: str):
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute('DELETE FROM deleted_records WHERE record_id = ?', (record_id,))
        conn.commit()
        
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Deleted record not found")
    
    return {"message": "Record permanently deleted"}


@app.get("/api/records/ledgers")
async def get_all_ledgers():
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            SELECT name
            FROM ledgers
            ORDER BY name
        ''')
        rows = cursor.fetchall()
    
    return [row["name"] for row in rows]


@app.post("/api/records/ledgers")
async def create_ledger(ledger: LedgerDTO):
    try:
        with get_db() as conn:
            cursor = conn.cursor()
            now = datetime.now().isoformat()
            cursor.execute('''
                INSERT INTO ledgers (name, created_at, updated_at)
                VALUES (?, ?, ?)
            ''', (ledger.name, now, now))
            conn.commit()
        
        return {"id": str(cursor.lastrowid), "name": ledger.name}
    except sqlite3.IntegrityError:
        raise HTTPException(status_code=400, detail="Ledger already exists")


@app.put("/api/records/ledgers/{old_name}")
async def update_ledger(old_name: str, ledger: LedgerDTO):
    with get_db() as conn:
        cursor = conn.cursor()
        now = datetime.now().isoformat()
        cursor.execute('''
            UPDATE ledgers
            SET name = ?, updated_at = ?
            WHERE name = ?
        ''', (ledger.name, now, old_name))
        conn.commit()
        
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Ledger not found")
    
    return {"name": ledger.name}


@app.delete("/api/records/ledgers/{name}")
async def delete_ledger(name: str):
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute('DELETE FROM ledgers WHERE name = ?', (name,))
        conn.commit()
        
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Ledger not found")
    
    return {"message": "Ledger deleted successfully"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=7378)
