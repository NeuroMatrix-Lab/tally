use axum::{
    routing::{get, post, put, delete},
    Router,
    Json,
    extract::{Path, State},
    http::StatusCode,
};
use serde::{Deserialize, Serialize};
use sqlx::{mysql::MySqlPoolOptions, MySqlPool, Row};
use chrono::{DateTime, Utc};
use std::sync::Arc;
use tower_http::cors::{Any, CorsLayer};
use anyhow::Result;

#[derive(Clone)]
struct AppState {
    db: MySqlPool,
}

// 记录模型
#[derive(Debug, Serialize, Deserialize, Clone)]
struct Record {
    id: String,
    #[serde(rename = "recordId")]
    record_id: String,
    date: String,
    category: String,
    #[serde(rename = "workContent")]
    work_content: String,
    amount: f64,
    ledger: String,
    #[serde(rename = "imageUrl")]
    image_url: Option<String>,
    #[serde(rename = "staffIds")]
    staff_ids: Vec<String>,
}

// 人员模型
#[derive(Debug, Serialize, Deserialize, Clone)]
struct Staff {
    id: String,
    name: String,
}

// 创建记录请求
#[derive(Debug, Deserialize)]
struct CreateRecordRequest {
    id: String,
    date: String,
    category: String,
    #[serde(rename = "workContent")]
    work_content: String,
    amount: f64,
    ledger: String,
    #[serde(rename = "imageUrl")]
    image_url: Option<String>,
    #[serde(rename = "staffIds")]
    staff_ids: Vec<String>,
}

// 更新记录请求
#[derive(Debug, Deserialize)]
struct UpdateRecordRequest {
    date: String,
    category: String,
    #[serde(rename = "workContent")]
    work_content: String,
    amount: f64,
    ledger: String,
    #[serde(rename = "imageUrl")]
    image_url: Option<String>,
    #[serde(rename = "staffIds")]
    staff_ids: Vec<String>,
}

// 创建人员请求
#[derive(Debug, Deserialize)]
struct CreateStaffRequest {
    name: String,
}

// 更新人员请求
#[derive(Debug, Deserialize)]
struct UpdateStaffRequest {
    name: String,
}

// 搜索记录请求
#[derive(Debug, Deserialize)]
struct SearchRecordsRequest {
    #[serde(rename = "startDate")]
    start_date: String,
    #[serde(rename = "endDate")]
    end_date: String,
    category: Option<String>,
    ledger: Option<String>,
}

#[tokio::main]
async fn main() -> Result<()> {
    // 从环境变量获取数据库连接信息
    let database_url = std::env::var("DATABASE_URL")
        .unwrap_or_else(|_| "mysql://tally_user:tally_password@localhost:3306/tally_db".to_string());

    println!("Connecting to database...");
    
    // 创建数据库连接池
    let pool = MySqlPoolOptions::new()
        .max_connections(5)
        .connect(&database_url)
        .await?;

    println!("Database connected successfully!");

    // 初始化数据库表
    init_database(&pool).await?;

    let state = Arc::new(AppState { db: pool });

    // 配置CORS
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    // 构建路由
    let app = Router::new()
        // 记录相关API
        .route("/api/records", get(get_all_records))
        .route("/api/records/recent", get(get_recent_records))
        .route("/api/records/search", post(search_records))
        .route("/api/records", post(create_record))
        .route("/api/records/:id", put(update_record))
        .route("/api/records/:id", delete(delete_record))
        // 已删除记录API
        .route("/api/records/deleted", get(get_deleted_records))
        .route("/api/records/:id/restore", post(restore_record))
        .route("/api/records/:id/permanent", delete(permanently_delete_record))
        // 账本相关API
        .route("/api/ledgers", get(get_all_ledgers))
        .route("/api/ledgers", post(create_ledger))
        .route("/api/ledgers/:name", put(update_ledger))
        .route("/api/ledgers/:name", delete(delete_ledger))
        // 人员相关API
        .route("/api/staff", get(get_all_staff))
        .route("/api/staff", post(create_staff))
        .route("/api/staff/:id", put(update_staff))
        .route("/api/staff/:id", delete(delete_staff))
        // 工作内容和类别
        .route("/api/work-contents", get(get_work_contents))
        .route("/api/categories", get(get_categories))
        // 健康检查
        .route("/health", get(health_check))
        .layer(cors)
        .with_state(state);

    let port = std::env::var("PORT").unwrap_or_else(|_| "7378".to_string());
    let listener = tokio::net::TcpListener::bind(format!("0.0.0.0:{}", port)).await?;
    
    println!("Server running on http://0.0.0.0:{}", port);
    
    axum::serve(listener, app).await?;
    
    Ok(())
}

async fn init_database(pool: &MySqlPool) -> Result<()> {
    // 创建记录表
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS records (
            id INT AUTO_INCREMENT PRIMARY KEY,
            record_id VARCHAR(255) NOT NULL UNIQUE,
            date DATETIME NOT NULL,
            category VARCHAR(255) NOT NULL,
            work_content TEXT NOT NULL,
            amount DECIMAL(10, 2) NOT NULL,
            ledger VARCHAR(255) NOT NULL,
            image_url TEXT,
            staff_ids JSON,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            deleted_at DATETIME DEFAULT NULL,
            INDEX idx_date (date),
            INDEX idx_category (category),
            INDEX idx_ledger (ledger),
            INDEX idx_deleted_at (deleted_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        "#
    )
    .execute(pool)
    .await?;

    // 创建已删除记录表
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS deleted_records (
            id INT AUTO_INCREMENT PRIMARY KEY,
            record_id VARCHAR(255) NOT NULL,
            date DATETIME NOT NULL,
            category VARCHAR(255) NOT NULL,
            work_content TEXT NOT NULL,
            amount DECIMAL(10, 2) NOT NULL,
            ledger VARCHAR(255) NOT NULL,
            image_url TEXT,
            staff_ids JSON,
            deleted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_record_id (record_id),
            INDEX idx_deleted_at (deleted_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        "#
    )
    .execute(pool)
    .await?;

    // 创建账本表
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS ledgers (
            id INT AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(255) NOT NULL UNIQUE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        "#
    )
    .execute(pool)
    .await?;

    // 创建人员表
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS staff (
            id INT AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(255) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        "#
    )
    .execute(pool)
    .await?;

    // 插入默认账本
    sqlx::query("INSERT IGNORE INTO ledgers (name) VALUES ('默认账本')")
        .execute(pool)
        .await?;

    println!("Database tables initialized successfully!");
    
    Ok(())
}

// 健康检查
async fn health_check(State(state): State<Arc<AppState>>) -> Result<Json<serde_json::Value>, StatusCode> {
    // 测试数据库连接
    match sqlx::query("SELECT 1").fetch_one(&state.db).await {
        Ok(_) => Ok(Json(serde_json::json!({
            "status": "healthy",
            "database": "connected"
        }))),
        Err(_) => Err(StatusCode::SERVICE_UNAVAILABLE),
    }
}

// 获取所有记录
async fn get_all_records(State(state): State<Arc<AppState>>) -> Result<Json<Vec<Record>>, StatusCode> {
    let rows = sqlx::query(
        r#"
        SELECT 
            record_id as "record_id!",
            date as "date!",
            category as "category!",
            work_content as "work_content!",
            amount as "amount!",
            ledger as "ledger!",
            image_url,
            staff_ids
        FROM records 
        WHERE deleted_at IS NULL 
        ORDER BY date DESC
        "#
    )
    .fetch_all(&state.db)
    .await
    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let records: Vec<Record> = rows
        .into_iter()
        .map(|row| {
            let staff_ids: Vec<String> = row.try_get::<String, _>("staff_ids")
                .ok()
                .and_then(|s| serde_json::from_str(&s).ok())
                .unwrap_or_default();

            Record {
                id: row.get("record_id"),
                record_id: row.get("record_id"),
                date: row.get::<DateTime<chrono::Utc>, _>("date").to_rfc3339(),
                category: row.get("category"),
                work_content: row.get("work_content"),
                amount: row.get::<f64, _>("amount"),
                ledger: row.get("ledger"),
                image_url: row.try_get::<Option<String>, _>("image_url").ok().flatten(),
                staff_ids,
            }
        })
        .collect();

    Ok(Json(records))
}

// 获取最近记录
async fn get_recent_records(
    State(state): State<Arc<AppState>>,
    axum::extract::Query(params): axum::extract::Query<std::collections::HashMap<String, String>>,
) -> Result<Json<Vec<Record>>, StatusCode> {
    let months: i32 = params.get("months")
        .and_then(|m| m.parse().ok())
        .unwrap_or(3);

    let rows = sqlx::query(
        r#"
        SELECT 
            record_id as "record_id!",
            date as "date!",
            category as "category!",
            work_content as "work_content!",
            amount as "amount!",
            ledger as "ledger!",
            image_url,
            staff_ids
        FROM records 
        WHERE deleted_at IS NULL 
        AND date >= DATE_SUB(NOW(), INTERVAL ? MONTH)
        ORDER BY date DESC
        "#
    )
    .bind(months)
    .fetch_all(&state.db)
    .await
    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let records: Vec<Record> = rows
        .into_iter()
        .map(|row| {
            let staff_ids: Vec<String> = row.try_get::<String, _>("staff_ids")
                .ok()
                .and_then(|s| serde_json::from_str(&s).ok())
                .unwrap_or_default();

            Record {
                id: row.get("record_id"),
                record_id: row.get("record_id"),
                date: row.get::<DateTime<chrono::Utc>, _>("date").to_rfc3339(),
                category: row.get("category"),
                work_content: row.get("work_content"),
                amount: row.get::<f64, _>("amount"),
                ledger: row.get("ledger"),
                image_url: row.try_get::<Option<String>, _>("image_url").ok().flatten(),
                staff_ids,
            }
        })
        .collect();

    Ok(Json(records))
}

// 搜索记录
async fn search_records(
    State(state): State<Arc<AppState>>,
    Json(req): Json<SearchRecordsRequest>,
) -> Result<Json<Vec<Record>>, StatusCode> {
    let mut query = String::from(
        r#"
        SELECT 
            record_id as "record_id!",
            date as "date!",
            category as "category!",
            work_content as "work_content!",
            amount as "amount!",
            ledger as "ledger!",
            image_url,
            staff_ids
        FROM records 
        WHERE deleted_at IS NULL 
        AND date BETWEEN ? AND ?
        "#
    );

    let start_date = DateTime::parse_from_rfc3339(&req.start_date)
        .map_err(|_| StatusCode::BAD_REQUEST)?
        .with_timezone(&Utc);
    let end_date = DateTime::parse_from_rfc3339(&req.end_date)
        .map_err(|_| StatusCode::BAD_REQUEST)?
        .with_timezone(&Utc);

    if req.category.is_some() {
        query.push_str(" AND category = ?");
    }
    if req.ledger.is_some() {
        query.push_str(" AND ledger = ?");
    }
    query.push_str(" ORDER BY date DESC");

    let mut sql_query = sqlx::query_as::<_, RecordRow>(&query)
        .bind(start_date)
        .bind(end_date);

    if let Some(category) = &req.category {
        sql_query = sql_query.bind(category);
    }
    if let Some(ledger) = &req.ledger {
        sql_query = sql_query.bind(ledger);
    }

    let rows = sql_query
        .fetch_all(&state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let records: Vec<Record> = rows
        .into_iter()
        .map(|row| row_to_record(row))
        .collect();

    Ok(Json(records))
}

// 创建记录
async fn create_record(
    State(state): State<Arc<AppState>>,
    Json(req): Json<CreateRecordRequest>,
) -> Result<Json<Record>, StatusCode> {
    let date = DateTime::parse_from_rfc3339(&req.date)
        .map_err(|_| StatusCode::BAD_REQUEST)?
        .with_timezone(&Utc);

    let staff_ids_json = serde_json::to_string(&req.staff_ids)
        .map_err(|_| StatusCode::BAD_REQUEST)?;

    sqlx::query(
        r#"
        INSERT INTO records (record_id, date, category, work_content, amount, ledger, image_url, staff_ids)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        "#
    )
    .bind(&req.id)
    .bind(date)
    .bind(&req.category)
    .bind(&req.work_content)
    .bind(req.amount)
    .bind(&req.ledger)
    .bind(&req.image_url)
    .bind(&staff_ids_json)
    .execute(&state.db)
    .await
    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let record = Record {
        id: req.id.clone(),
        record_id: req.id,
        date: req.date,
        category: req.category,
        work_content: req.work_content,
        amount: req.amount,
        ledger: req.ledger,
        image_url: req.image_url,
        staff_ids: req.staff_ids,
    };

    Ok(Json(record))
}

// 更新记录
async fn update_record(
    State(state): State<Arc<AppState>>,
    Path(id): Path<String>,
    Json(req): Json<UpdateRecordRequest>,
) -> Result<Json<Record>, StatusCode> {
    let date = DateTime::parse_from_rfc3339(&req.date)
        .map_err(|_| StatusCode::BAD_REQUEST)?
        .with_timezone(&Utc);

    let staff_ids_json = serde_json::to_string(&req.staff_ids)
        .map_err(|_| StatusCode::BAD_REQUEST)?;

    sqlx::query(
        r#"
        UPDATE records 
        SET date = ?, category = ?, work_content = ?, amount = ?, ledger = ?, image_url = ?, staff_ids = ?
        WHERE record_id = ? AND deleted_at IS NULL
        "#
    )
    .bind(date)
    .bind(&req.category)
    .bind(&req.work_content)
    .bind(req.amount)
    .bind(&req.ledger)
    .bind(&req.image_url)
    .bind(&staff_ids_json)
    .bind(&id)
    .execute(&state.db)
    .await
    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let record = Record {
        id: id.clone(),
        record_id: id,
        date: req.date,
        category: req.category,
        work_content: req.work_content,
        amount: req.amount,
        ledger: req.ledger,
        image_url: req.image_url,
        staff_ids: req.staff_ids,
    };

    Ok(Json(record))
}

// 删除记录（软删除）
async fn delete_record(
    State(state): State<Arc<AppState>>,
    Path(id): Path<String>,
) -> Result<StatusCode, StatusCode> {
    // 先获取记录信息
    let row = sqlx::query(
        r#"
        SELECT record_id, date, category, work_content, amount, ledger, image_url, staff_ids
        FROM records 
        WHERE record_id = ? AND deleted_at IS NULL
        "#
    )
    .bind(&id)
    .fetch_one(&state.db)
    .await
    .map_err(|_| StatusCode::NOT_FOUND)?;

    let record_id: String = row.get("record_id");
    let date: DateTime<Utc> = row.get("date");
    let category: String = row.get("category");
    let work_content: String = row.get("work_content");
    let amount: f64 = row.get("amount");
    let ledger: String = row.get("ledger");
    let image_url: Option<String> = row.try_get::<Option<String>, _>("image_url").ok().flatten();
    let staff_ids: Option<String> = row.try_get::<Option<String>, _>("staff_ids").ok().flatten();

    // 插入到deleted_records表
    sqlx::query(
        r#"
        INSERT INTO deleted_records (record_id, date, category, work_content, amount, ledger, image_url, staff_ids, deleted_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())
        "#
    )
    .bind(&record_id)
    .bind(date)
    .bind(&category)
    .bind(&work_content)
    .bind(amount)
    .bind(&ledger)
    .bind(&image_url)
    .bind(&staff_ids)
    .execute(&state.db)
    .await
    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    // 软删除记录
    sqlx::query("UPDATE records SET deleted_at = NOW() WHERE record_id = ?")
        .bind(&id)
        .execute(&state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(StatusCode::NO_CONTENT)
}

// 获取已删除记录
async fn get_deleted_records(State(state): State<Arc<AppState>>) -> Result<Json<Vec<Record>>, StatusCode> {
    let rows = sqlx::query(
        r#"
        SELECT 
            record_id as "record_id!",
            date as "date!",
            category as "category!",
            work_content as "work_content!",
            amount as "amount!",
            ledger as "ledger!",
            image_url,
            staff_ids
        FROM deleted_records 
        ORDER BY deleted_at DESC
        "#
    )
    .fetch_all(&state.db)
    .await
    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let records: Vec<Record> = rows
        .into_iter()
        .map(|row| {
            let staff_ids: Vec<String> = row.try_get::<String, _>("staff_ids")
                .ok()
                .and_then(|s| serde_json::from_str(&s).ok())
                .unwrap_or_default();

            Record {
                id: row.get("record_id"),
                record_id: row.get("record_id"),
                date: row.get::<DateTime<chrono::Utc>, _>("date").to_rfc3339(),
                category: row.get("category"),
                work_content: row.get("work_content"),
                amount: row.get::<f64, _>("amount"),
                ledger: row.get("ledger"),
                image_url: row.try_get::<Option<String>, _>("image_url").ok().flatten(),
                staff_ids,
            }
        })
        .collect();

    Ok(Json(records))
}

// 恢复已删除记录
async fn restore_record(
    State(state): State<Arc<AppState>>,
    Path(id): Path<String>,
) -> Result<StatusCode, StatusCode> {
    // 从deleted_records表获取记录
    let row = sqlx::query(
        r#"
        SELECT record_id, date, category, work_content, amount, ledger, image_url, staff_ids
        FROM deleted_records 
        WHERE record_id = ?
        "#
    )
    .bind(&id)
    .fetch_one(&state.db)
    .await
    .map_err(|_| StatusCode::NOT_FOUND)?;

    let record_id: String = row.get("record_id");
    let date: DateTime<Utc> = row.get("date");
    let category: String = row.get("category");
    let work_content: String = row.get("work_content");
    let amount: f64 = row.get("amount");
    let ledger: String = row.get("ledger");
    let image_url: Option<String> = row.try_get::<Option<String>, _>("image_url").ok().flatten();
    let staff_ids: Option<String> = row.try_get::<Option<String>, _>("staff_ids").ok().flatten();

    // 插入到records表
    sqlx::query(
        r#"
        INSERT INTO records (record_id, date, category, work_content, amount, ledger, image_url, staff_ids, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
        ON DUPLICATE KEY UPDATE
        deleted_at = NULL,
        date = VALUES(date),
        category = VALUES(category),
        work_content = VALUES(work_content),
        amount = VALUES(amount),
        ledger = VALUES(ledger),
        image_url = VALUES(image_url),
        staff_ids = VALUES(staff_ids),
        updated_at = NOW()
        "#
    )
    .bind(&record_id)
    .bind(date)
    .bind(&category)
    .bind(&work_content)
    .bind(amount)
    .bind(&ledger)
    .bind(&image_url)
    .bind(&staff_ids)
    .execute(&state.db)
    .await
    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    // 从deleted_records表删除
    sqlx::query("DELETE FROM deleted_records WHERE record_id = ?")
        .bind(&id)
        .execute(&state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(StatusCode::NO_CONTENT)
}

// 永久删除记录
async fn permanently_delete_record(
    State(state): State<Arc<AppState>>,
    Path(id): Path<String>,
) -> Result<StatusCode, StatusCode> {
    sqlx::query("DELETE FROM deleted_records WHERE record_id = ?")
        .bind(&id)
        .execute(&state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(StatusCode::NO_CONTENT)
}

// 获取所有账本
async fn get_all_ledgers(State(state): State<Arc<AppState>>) -> Result<Json<Vec<String>>, StatusCode> {
    let rows = sqlx::query("SELECT name FROM ledgers ORDER BY name")
        .fetch_all(&state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let ledgers: Vec<String> = rows
        .into_iter()
        .map(|row| row.get("name"))
        .collect();

    Ok(Json(ledgers))
}

// 创建账本
async fn create_ledger(
    State(state): State<Arc<AppState>>,
    Json(name): Json<String>,
) -> Result<Json<String>, StatusCode> {
    sqlx::query("INSERT INTO ledgers (name) VALUES (?) ON DUPLICATE KEY UPDATE name = name")
        .bind(&name)
        .execute(&state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(name))
}

// 更新账本
async fn update_ledger(
    State(state): State<Arc<AppState>>,
    Path(old_name): Path<String>,
    Json(new_name): Json<String>,
) -> Result<Json<String>, StatusCode> {
    sqlx::query("UPDATE ledgers SET name = ? WHERE name = ?")
        .bind(&new_name)
        .bind(&old_name)
        .execute(&state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    // 更新所有使用该账本的记录
    sqlx::query("UPDATE records SET ledger = ? WHERE ledger = ?")
        .bind(&new_name)
        .bind(&old_name)
        .execute(&state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(new_name))
}

// 删除账本
async fn delete_ledger(
    State(state): State<Arc<AppState>>,
    Path(name): Path<String>,
) -> Result<StatusCode, StatusCode> {
    sqlx::query("DELETE FROM ledgers WHERE name = ?")
        .bind(&name)
        .execute(&state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(StatusCode::NO_CONTENT)
}

// 获取所有人员
async fn get_all_staff(State(state): State<Arc<AppState>>) -> Result<Json<Vec<Staff>>, StatusCode> {
    let rows = sqlx::query("SELECT id, name FROM staff ORDER BY name")
        .fetch_all(&state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let staff: Vec<Staff> = rows
        .into_iter()
        .map(|row| Staff {
            id: row.get::<i32, _>("id").to_string(),
            name: row.get("name"),
        })
        .collect();

    Ok(Json(staff))
}

// 创建人员
async fn create_staff(
    State(state): State<Arc<AppState>>,
    Json(req): Json<CreateStaffRequest>,
) -> Result<Json<Staff>, StatusCode> {
    let result = sqlx::query("INSERT INTO staff (name) VALUES (?)")
        .bind(&req.name)
        .execute(&state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let staff = Staff {
        id: result.last_insert_id().to_string(),
        name: req.name,
    };

    Ok(Json(staff))
}

// 更新人员
async fn update_staff(
    State(state): State<Arc<AppState>>,
    Path(id): Path<String>,
    Json(req): Json<UpdateStaffRequest>,
) -> Result<Json<Staff>, StatusCode> {
    let id: i32 = id.parse().map_err(|_| StatusCode::BAD_REQUEST)?;

    sqlx::query("UPDATE staff SET name = ? WHERE id = ?")
        .bind(&req.name)
        .bind(id)
        .execute(&state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let staff = Staff {
        id: id.to_string(),
        name: req.name,
    };

    Ok(Json(staff))
}

// 删除人员
async fn delete_staff(
    State(state): State<Arc<AppState>>,
    Path(id): Path<String>,
) -> Result<StatusCode, StatusCode> {
    let id: i32 = id.parse().map_err(|_| StatusCode::BAD_REQUEST)?;

    sqlx::query("DELETE FROM staff WHERE id = ?")
        .bind(id)
        .execute(&state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(StatusCode::NO_CONTENT)
}

// 获取工作内容列表
async fn get_work_contents(State(state): State<Arc<AppState>>) -> Result<Json<Vec<String>>, StatusCode> {
    let rows = sqlx::query(
        r#"
        SELECT DISTINCT work_content FROM records 
        WHERE deleted_at IS NULL 
        ORDER BY work_content
        "#
    )
    .fetch_all(&state.db)
    .await
    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let contents: Vec<String> = rows
        .into_iter()
        .map(|row| row.get("work_content"))
        .collect();

    Ok(Json(contents))
}

// 获取类别列表
async fn get_categories(State(state): State<Arc<AppState>>) -> Result<Json<Vec<String>>, StatusCode> {
    let rows = sqlx::query(
        r#"
        SELECT DISTINCT category FROM records 
        WHERE deleted_at IS NULL 
        ORDER BY category
        "#
    )
    .fetch_all(&state.db)
    .await
    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let categories: Vec<String> = rows
        .into_iter()
        .map(|row| row.get("category"))
        .collect();

    Ok(Json(categories))
}

// 辅助结构体和函数
#[derive(sqlx::FromRow)]
struct RecordRow {
    record_id: String,
    date: DateTime<Utc>,
    category: String,
    work_content: String,
    amount: f64,
    ledger: String,
    image_url: Option<String>,
    staff_ids: Option<String>,
}

fn row_to_record(row: RecordRow) -> Record {
    let staff_ids: Vec<String> = row.staff_ids
        .and_then(|s| serde_json::from_str(&s).ok())
        .unwrap_or_default();

    Record {
        id: row.record_id.clone(),
        record_id: row.record_id,
        date: row.date.to_rfc3339(),
        category: row.category,
        work_content: row.work_content,
        amount: row.amount,
        ledger: row.ledger,
        image_url: row.image_url,
        staff_ids,
    }
}
