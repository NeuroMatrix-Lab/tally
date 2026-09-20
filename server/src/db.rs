use anyhow::Result;
use chrono::{DateTime, Utc};
use sqlx::{MySqlPool, Row};

use crate::models::Record;

pub async fn init_database(pool: &MySqlPool) -> Result<()> {
    tracing::info!("Initializing database tables...");

    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS records (
            id INT AUTO_INCREMENT PRIMARY KEY,
            record_id VARCHAR(255) NOT NULL UNIQUE,
            date DATETIME NOT NULL,
            category VARCHAR(255) NOT NULL,
            work_content TEXT NOT NULL,
            amount DOUBLE NOT NULL,
            ledger VARCHAR(255) NOT NULL,
            image_url TEXT,
            staff_ids JSON,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            deleted_at DATETIME DEFAULT NULL,
            INDEX idx_date (date),
            INDEX idx_category (category),
            INDEX idx_ledger (ledger),
            INDEX idx_deleted_at (deleted_at),
            INDEX idx_updated_at (updated_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        "#,
    )
    .execute(pool)
    .await?;

    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS ledgers (
            id INT AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(255) NOT NULL UNIQUE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        "#,
    )
    .execute(pool)
    .await?;

    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS staff (
            id INT AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(255) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            deleted_at DATETIME DEFAULT NULL,
            INDEX idx_staff_deleted_at (deleted_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        "#,
    )
    .execute(pool)
    .await?;

    sqlx::query("INSERT IGNORE INTO ledgers (name) VALUES ('默认账本')")
        .execute(pool)
        .await?;

    // 旧库可能是 DECIMAL，sqlx 读 f64 会 panic；统一成 DOUBLE
    if let Err(e) = sqlx::query("ALTER TABLE records MODIFY amount DOUBLE NOT NULL")
        .execute(pool)
        .await
    {
        tracing::warn!("skip amount column alter: {:?}", e);
    }

    println!("Database tables initialized successfully!");

    Ok(())
}

pub fn decode_amount(row: &sqlx::mysql::MySqlRow) -> f64 {
    // 表结构是 DECIMAL，sqlx 不能直接当 f64 解，会 panic
    if let Ok(v) = row.try_get::<f64, _>("amount") {
        return v;
    }
    if let Ok(v) = row.try_get::<String, _>("amount") {
        return v.trim().parse().unwrap_or(0.0);
    }
    if let Ok(v) = row.try_get::<i64, _>("amount") {
        return v as f64;
    }
    if let Ok(v) = row.try_get::<i32, _>("amount") {
        return v as f64;
    }
    0.0
}

pub fn row_to_record(row: sqlx::mysql::MySqlRow) -> Record {
    let staff_ids: Vec<String> = row
        .try_get::<String, _>("staff_ids")
        .ok()
        .and_then(|s| serde_json::from_str(&s).ok())
        .unwrap_or_default();

    // 用 try_get，避免异常字段导致进程 panic
    let updated_at: Option<DateTime<Utc>> = row.try_get("updated_at").ok().flatten();
    let deleted_at: Option<DateTime<Utc>> = row.try_get("deleted_at").ok().flatten();
    let date: DateTime<Utc> = row
        .try_get::<DateTime<Utc>, _>("date")
        .unwrap_or_else(|_| Utc::now());
    let amount = decode_amount(&row);

    Record {
        id: row.try_get::<String, _>("record_id").unwrap_or_default(),
        record_id: row.try_get::<String, _>("record_id").unwrap_or_default(),
        date: date.to_rfc3339(),
        category: row.try_get("category").unwrap_or_default(),
        work_content: row.try_get("work_content").unwrap_or_default(),
        amount,
        ledger: row.try_get("ledger").unwrap_or_default(),
        image_url: row.try_get::<Option<String>, _>("image_url").ok().flatten(),
        staff_ids,
        updated_at: updated_at.map(|dt| dt.to_rfc3339()),
        deleted_at: deleted_at.map(|dt| dt.to_rfc3339()),
    }
}

pub async fn get_all_records_from_db(
    db: &MySqlPool,
) -> Result<Vec<Record>, axum::http::StatusCode> {
    let rows = sqlx::query(
        r#"
        SELECT
            record_id, date, category, work_content, amount, ledger, image_url, staff_ids, updated_at, deleted_at
        FROM records
        WHERE deleted_at IS NULL
        ORDER BY date DESC
        "#,
    )
    .fetch_all(db)
    .await
    .map_err(|_| axum::http::StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(rows.into_iter().map(row_to_record).collect())
}

pub async fn get_all_ledgers_from_db(
    db: &MySqlPool,
) -> Result<Vec<String>, axum::http::StatusCode> {
    let rows = sqlx::query("SELECT name FROM ledgers ORDER BY name")
        .fetch_all(db)
        .await
        .map_err(|_| axum::http::StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(rows.into_iter().map(|row| row.get("name")).collect())
}

pub async fn get_all_staff_from_db(
    db: &MySqlPool,
    since: Option<DateTime<Utc>>,
) -> Result<Vec<crate::models::Staff>, axum::http::StatusCode> {
    use crate::models::Staff;

    let query = if let Some(since) = since {
        sqlx::query(
            "SELECT id, name, updated_at FROM staff WHERE updated_at >= ? AND deleted_at IS NULL ORDER BY name",
        ).bind(since)
    } else {
        sqlx::query(
            "SELECT id, name, updated_at FROM staff WHERE deleted_at IS NULL ORDER BY name",
        )
    };

    let rows = query
        .fetch_all(db)
        .await
        .map_err(|_| axum::http::StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(rows
        .into_iter()
        .map(|row| {
            let updated_at: Option<DateTime<Utc>> = row.get("updated_at");
            Staff {
                id: row.get::<i32, _>("id").to_string(),
                name: row.get("name"),
                updated_at: updated_at.map(|dt| dt.to_rfc3339()),
            }
        })
        .collect())
}
