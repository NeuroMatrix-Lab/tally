from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime, timedelta
import sqlite3
import json
from contextlib import contextmanager
import os

app = FastAPI(title="Tally Server", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

DATABASE_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "tally.db")


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
                created_at TEXT,
                updated_at TEXT
            )
        ''')
        conn.commit()


class RecordDTO(BaseModel):
    recordId: str
    date: datetime
    category: str
    workContent: str
    amount: float
    ledger: str


@app.on_event("startup")
async def startup_event():
    init_db()


@app.get("/api/records/recent")
async def get_recent_records(months: int = 3):
    start_date = datetime.now() - timedelta(days=months * 30)
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            SELECT record_id, date, category, work_content, amount, ledger
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
            SELECT record_id, date, category, work_content, amount, ledger
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


@app.get("/api/records/ledgers")
async def get_all_ledgers():
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            SELECT DISTINCT ledger
            FROM records
            ORDER BY ledger
        ''')
        rows = cursor.fetchall()
    
    return [row["ledger"] for row in rows]


@app.post("/api/records")
async def create_record(record: RecordDTO):
    try:
        with get_db() as conn:
            cursor = conn.cursor()
            now = datetime.now().isoformat()
            cursor.execute('''
                INSERT INTO records (record_id, date, category, work_content, amount, ledger, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                record.recordId,
                record.date.isoformat(),
                record.category,
                record.workContent,
                record.amount,
                record.ledger,
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
        }
    except sqlite3.IntegrityError:
        raise HTTPException(status_code=400, detail="Record ID already exists")


@app.put("/api/records/{record_id}")
async def update_record(record_id: str, record: RecordDTO):
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            UPDATE records
            SET date = ?, category = ?, work_content = ?, amount = ?, ledger = ?, updated_at = ?
            WHERE record_id = ?
        ''', (
            record.date.isoformat(),
            record.category,
            record.workContent,
            record.amount,
            record.ledger,
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
    }


@app.delete("/api/records/{record_id}")
async def delete_record(record_id: str):
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute('DELETE FROM records WHERE record_id = ?', (record_id,))
        conn.commit()
        
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Record not found")
    
    return {"message": "Record deleted successfully"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=7378)