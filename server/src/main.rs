use axum::{
    extract::{
        ws::{Message, WebSocket, WebSocketUpgrade},
        Path, State,
    },
    response::IntoResponse,
    routing::{get, post, put, delete},
    Router,
    Json,
    http::StatusCode,
};
use serde::{Deserialize, Serialize};
use sqlx::{mysql::MySqlPoolOptions, MySqlPool, Row};
use chrono::{DateTime, Utc};
use std::sync::Arc;
use tower_http::cors::{Any, CorsLayer};
use tower_http::trace::TraceLayer;
use tower_http::compression::CompressionLayer;
use anyhow::Result;
use tracing::{info, error, Level};
use tracing_subscriber::FmtSubscriber;
use futures_util::{SinkExt, StreamExt};
use tokio::sync::broadcast;

#[derive(Clone)]
struct AppState {
    db: MySqlPool,
    request_count: Arc<std::sync::atomic::AtomicU64>,
    tx: broadcast::Sender<SyncMessage>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct SyncMessage {
    event_type: String,
    entity_type: String,
    entity_id: Option<String>,
    timestamp: DateTime<Utc>,
}

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
    #[serde(rename = "updatedAt")]
    updated_at: Option<String>,
    #[serde(rename = "deletedAt")]
    deleted_at: Option<String>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
struct Staff {
    id: String,
    name: String,
    #[serde(rename = "updatedAt")]
    updated_at: Option<String>,
}

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

#[derive(Debug, Deserialize)]
struct CreateStaffRequest {
    name: String,
}

#[derive(Debug, Deserialize)]
struct UpdateStaffRequest {
    name: String,
}

#[derive(Debug, Deserialize)]
struct SearchRecordsRequest {
    #[serde(rename = "startDate")]
    start_date: String,
    #[serde(rename = "endDate")]
    end_date: String,
    category: Option<String>,
    ledger: Option<String>,
}

#[derive(Debug, Deserialize)]
struct IncrementalSyncRequest {
    #[serde(rename = "lastSyncTime")]
    last_sync_time: Option<String>,
}

#[derive(Debug, Serialize)]
struct IncrementalSyncResponse {
    records: Vec<Record>,
    staff: Vec<Staff>,
    ledgers: Vec<String>,
    #[serde(rename = "deletedRecordIds")]
    deleted_record_ids: Vec<String>,
    #[serde(rename = "deletedStaffIds")]
    deleted_staff_ids: Vec<String>,
    #[serde(rename = "serverTime")]
    server_time: String,
}

#[tokio::main]
async fn main() -> Result<()> {
    let _subscriber = FmtSubscriber::builder()
        .with_max_level(Level::INFO)
        .with_target(false)
        .with_thread_ids(true)
        .with_file(true)
        .with_line_number(true)
        .json()
        .init();

    info!("Starting Tally Server with WebSocket Sync...");

    let database_url = std::env::var("DATABASE_URL")
        .expect("DATABASE_URL must be set. Example: mysql://user:***@host:3306/tally");

    println!("Connecting to database...");

    let pool = MySqlPoolOptions::new()
        .max_connections(5)
        .connect(&database_url)
        .await?;

    info!("Database connected successfully!");

    init_database(&pool).await?;

    let (tx, _rx) = broadcast::channel(100);

    let state = Arc::new(AppState {
        db: pool,
        request_count: Arc::new(std::sync::atomic::AtomicU64::new(0)),
        tx,
    });

    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    let app = Router::new()
        .route("/api/v1/health", get(health_check))
        .route("/api/v1/metrics", get(get_metrics))
        .route("/api/v1/ws", get(ws_handler))
        .route("/api/v1/sync", post(incremental_sync))
        .route("/api/v1/records", get(get_all_records))
        .route("/api/v1/records/recent", get(get_recent_records))
        .route("/api/v1/records/search", post(search_records))
        .route("/api/v1/records", post(create_record))
        .route("/api/v1/records/:id", put(update_record))
        .route("/api/v1/records/:id", delete(delete_record))
        .route("/api/v1/records/deleted", get(get_deleted_records))
        .route("/api/v1/records/:id/restore", post(restore_record))
        .route("/api/v1/records/:id/permanent", delete(permanently_delete_record))
        .route("/api/v1/ledgers", get(get_all_ledgers))
        .route("/api/v1/ledgers", post(create_ledger))
        .route("/api/v1/ledgers/:name", put(update_ledger))
        .route("/api/v1/ledgers/:name", delete(delete_ledger))
        .route("/api/v1/staff", get(get_all_staff))
        .route("/api/v1/staff", post(create_staff))
        .route("/api/v1/staff/:id", put(update_staff))
        .route("/api/v1/staff/:id", delete(delete_staff))
        .route("/api/v1/work-contents", get(get_work_contents))
        .route("/api/v1/categories", get(get_categories))
        .layer(cors)
        .layer(CompressionLayer::new())
        .layer(TraceLayer::new_for_http())
        .with_state(state);

    let port = std::env::var("PORT").unwrap_or_else(|_| "7378".to_string());
    let addr = format!("0.0.0.0:{}", port);

    info!("Server listening on {}", addr);
    let listener = tokio::net::TcpListener::bind(&addr).await?;

    axum::serve(listener, app).await?;

    Ok(())
}

async fn init_database(pool: &MySqlPool) -> Result<()> {
    info!("Initializing database tables...");

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
            INDEX idx_deleted_at (deleted_at),
            INDEX idx_updated_at (updated_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        "#
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
        "#
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
        "#
    )
    .execute(pool)
    .await?;

    sqlx::query("INSERT IGNORE INTO ledgers (name) VALUES ('默认账本')")
        .execute(pool)
        .await?;

    println!("Database tables initialized successfully!");
    
    Ok(())
}

async fn health_check(State(state): State<Arc<AppState>>) -> Result<Json<serde_json::Value>, StatusCode> {
    let request_count = state.request_count.load(std::sync::atomic::Ordering::Relaxed);

    match sqlx::query("SELECT 1").fetch_one(&state.db).await {
        Ok(_) => {
            info!("Health check passed");
            Ok(Json(serde_json::json!({
                "status": "healthy",
                "database": "connected",
                "uptime": "running",
                "requestCount": request_count
            })))
        },
        Err(e) => {
            error!("Health check failed: {:?}", e);
            Err(StatusCode::SERVICE_UNAVAILABLE)
        }
    }
}

async fn get_metrics(State(state): State<Arc<AppState>>) -> Result<Json<serde_json::Value>, StatusCode> {
    let request_count = state.request_count.load(std::sync::atomic::Ordering::Relaxed);

    let db_stats = sqlx::query("SELECT COUNT(*) as count FROM records WHERE deleted_at IS NULL")
        .fetch_one(&state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let record_count: i64 = db_stats.get("count");

    Ok(Json(serde_json::json!({
        "server": {
            "status": "running",
            "requestCount": request_count
        },
        "database": {
            "totalRecords": record_count
        },
        "version": "1.0.0"
    })))
}

async fn ws_handler(
    ws: WebSocketUpgrade,
    State(state): State<Arc<AppState>>,
) -> impl IntoResponse {
    ws.on_upgrade(move |socket| handle_socket(socket, state))
}

async fn handle_socket(socket: WebSocket, state: Arc<AppState>) {
    let mut rx = state.tx.subscribe();
    
    info!("New WebSocket client connected");

    let (mut sender, mut receiver) = socket.split();

    let mut send_task = tokio::spawn(async move {
        while let Ok(msg) = rx.recv().await {
            let msg_str = serde_json::to_string(&msg).unwrap();
            if sender.send(Message::Text(msg_str)).await.is_err() {
                break;
            }
        }
    });

    let mut recv_task = tokio::spawn(async move {
        while let Some(Ok(msg)) = receiver.next().await {
            match msg {
                Message::Text(text) => {
                    info!("Received message from client: {}", text);
                }
                Message::Close(_) => {
                    break;
                }
                _ => {}
            }
        }
    });

    tokio::select! {
        _ = (&mut send_task) => recv_task.abort(),
        _ = (&mut recv_task) => send_task.abort(),
    }
    
    info!("WebSocket client disconnected");
}

fn broadcast_sync_event(state: &Arc<AppState>, entity_type: &str, event_type: &str, entity_id: Option<String>) {
    let msg = SyncMessage {
        event_type: event_type.to_string(),
        entity_type: entity_type.to_string(),
        entity_id,
        timestamp: Utc::now(),
    };
    
    let _ = state.tx.send(msg);
    info!("Broadcasted {} event for {}", event_type, entity_type);
}

async fn incremental_sync(
    State(state): State<Arc<AppState>>,
    Json(req): Json<IncrementalSyncRequest>,
) -> Result<Json<IncrementalSyncResponse>, StatusCode> {
    let last_sync_time = req.last_sync_time
        .and_then(|t| DateTime::parse_from_rfc3339(&t).ok())
        .map(|dt| dt.with_timezone(&Utc));

    let server_time = Utc::now();

    let (records, deleted_record_ids) = if let Some(since) = last_sync_time {
        let records = sqlx::query(
            r#"
            SELECT record_id, date, category, work_content, amount, ledger, image_url, staff_ids, updated_at, deleted_at
            FROM records
            WHERE updated_at > ?
            ORDER BY updated_at DESC
            "#
        )
        .bind(since)
        .fetch_all(&state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

        let mut active_records = Vec::new();
        let mut deleted_ids = Vec::new();

        for row in records {
            let record_id: String = row.get("record_id");
            let deleted_at: Option<DateTime<Utc>> = row.get("deleted_at");
            
            if deleted_at.is_some() {
                deleted_ids.push(record_id);
            } else {
                active_records.push(row_to_record(row));
            }
        }

        (active_records, deleted_ids)
    } else {
        let records = get_all_records_from_db(&state.db).await?;
        (records, Vec::new())
    };

    let staff = get_all_staff_from_db(&state.db, last_sync_time).await?;
    
    let ledgers = get_all_ledgers_from_db(&state.db).await?;

    let deleted_staff_ids = if let Some(since) = last_sync_time {
        let rows = sqlx::query("SELECT id FROM staff WHERE deleted_at > ? AND deleted_at IS NOT NULL")
            .bind(since)
            .fetch_all(&state.db)
            .await
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
        rows.into_iter().map(|row| row.get::<i32, _>("id").to_string()).collect()
    } else {
        Vec::new()
    };

    Ok(Json(IncrementalSyncResponse {
        records,
        staff,
        ledgers,
        deleted_record_ids,
        deleted_staff_ids,
        server_time: server_time.to_rfc3339(),
    }))
}

async fn get_all_records(State(state): State<Arc<AppState>>) -> Result<Json<Vec<Record>>, StatusCode> {
    let records = get_all_records_from_db(&state.db).await?;
    Ok(Json(records))
}

async fn get_all_records_from_db(db: &MySqlPool) -> Result<Vec<Record>, StatusCode> {
    let rows = sqlx::query(
        r#"
        SELECT 
            record_id, date, category, work_content, amount, ledger, image_url, staff_ids, updated_at, deleted_at
        FROM records 
        WHERE deleted_at IS NULL 
        ORDER BY date DESC
        "#
    )
    .fetch_all(db)
    .await
    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let records = rows.into_iter().map(row_to_record).collect();
    Ok(records)
}

fn row_to_record(row: sqlx::mysql::MySqlRow) -> Record {
    let staff_ids: Vec<String> = row.try_get::<String, _>("staff_ids")
        .ok()
        .and_then(|s| serde_json::from_str(&s).ok())
        .unwrap_or_default();

    let updated_at: Option<DateTime<Utc>> = row.get("updated_at");
    let deleted_at: Option<DateTime<Utc>> = row.get("deleted_at");

    Record {
        id: row.get("record_id"),
        record_id: row.get("record_id"),
        date: row.get::<DateTime<Utc>, _>("date").to_rfc3339(),
        category: row.get("category"),
        work_content: row.get("work_content"),
        amount: row.get::<f64, _>("amount"),
        ledger: row.get("ledger"),
        image_url: row.try_get::<Option<String>, _>("image_url").ok().flatten(),
        staff_ids,
        updated_at: updated_at.map(|dt| dt.to_rfc3339()),
        deleted_at: deleted_at.map(|dt| dt.to_rfc3339()),
    }
}

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
            record_id, date, category, work_content, amount, ledger, image_url, staff_ids, updated_at, deleted_at
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

    let records = rows.into_iter().map(row_to_record).collect();
    Ok(Json(records))
}

async fn search_records(
    State(state): State<Arc<AppState>>,
    Json(req): Json<SearchRecordsRequest>,
) -> Result<Json<Vec<Record>>, StatusCode> {
    let mut query = String::from(
        r#"
        SELECT 
            record_id, date, category, work_content, amount, ledger, image_url, staff_ids, updated_at, deleted_at
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

    let mut sql_query = sqlx::query(&query)
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

    let records = rows.into_iter().map(row_to_record).collect();
    Ok(Json(records))
}

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
        record_id: req.id.clone(),
        date: req.date,
        category: req.category,
        work_content: req.work_content,
        amount: req.amount,
        ledger: req.ledger,
        image_url: req.image_url,
        staff_ids: req.staff_ids,
        updated_at: Some(Utc::now().to_rfc3339()),
        deleted_at: None,
    };

    broadcast_sync_event(&state, "record", "created", Some(req.id));

    Ok(Json(record))
}

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
        record_id: id.clone(),
        date: req.date,
        category: req.category,
        work_content: req.work_content,
        amount: req.amount,
        ledger: req.ledger,
        image_url: req.image_url,
        staff_ids: req.staff_ids,
        updated_at: Some(Utc::now().to_rfc3339()),
        deleted_at: None,
    };

    broadcast_sync_event(&state, "record", "updated", Some(id));

    Ok(Json(record))
}

async fn delete_record(
    State(state): State<Arc<AppState>>,
    Path(id): Path<String>,
) -> Result<StatusCode, StatusCode> {
    let result = sqlx::query("UPDATE records SET deleted_at = NOW() WHERE record_id = ? AND deleted_at IS NULL")
        .bind(&id)
        .execute(&state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    if result.rows_affected() == 0 {
        return Err(StatusCode::NOT_FOUND);
    }

    broadcast_sync_event(&state, "record", "deleted", Some(id));

    Ok(StatusCode::NO_CONTENT)
}

async fn get_deleted_records(State(state): State<Arc<AppState>>) -> Result<Json<Vec<Record>>, StatusCode> {
    let rows = sqlx::query(
        r#"
        SELECT 
            record_id, date, category, work_content, amount, ledger, image_url, staff_ids, updated_at, deleted_at
        FROM records 
        WHERE deleted_at IS NOT NULL
        ORDER BY deleted_at DESC
        "#
    )
    .fetch_all(&state.db)
    .await
    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let records = rows.into_iter().map(row_to_record).collect();
    Ok(Json(records))
}

async fn restore_record(
    State(state): State<Arc<AppState>>,
    Path(id): Path<String>,
) -> Result<StatusCode, StatusCode> {
    let result = sqlx::query("UPDATE records SET deleted_at = NULL WHERE record_id = ? AND deleted_at IS NOT NULL")
        .bind(&id)
        .execute(&state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    if result.rows_affected() == 0 {
        return Err(StatusCode::NOT_FOUND);
    }

    broadcast_sync_event(&state, "record", "restored", Some(id));

    Ok(StatusCode::NO_CONTENT)
}

async fn permanently_delete_record(
    State(state): State<Arc<AppState>>,
    Path(id): Path<String>,
) -> Result<StatusCode, StatusCode> {
    let result = sqlx::query("DELETE FROM records WHERE record_id = ? AND deleted_at IS NOT NULL")
        .bind(&id)
        .execute(&state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    if result.rows_affected() == 0 {
        return Err(StatusCode::NOT_FOUND);
    }

    Ok(StatusCode::NO_CONTENT)
}

async fn get_all_ledgers(State(state): State<Arc<AppState>>) -> Result<Json<Vec<String>>, StatusCode> {
    let ledgers = get_all_ledgers_from_db(&state.db).await?;
    Ok(Json(ledgers))
}

async fn get_all_ledgers_from_db(db: &MySqlPool) -> Result<Vec<String>, StatusCode> {
    let rows = sqlx::query("SELECT name FROM ledgers ORDER BY name")
        .fetch_all(db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let ledgers = rows.into_iter().map(|row| row.get("name")).collect();
    Ok(ledgers)
}

async fn create_ledger(
    State(state): State<Arc<AppState>>,
    Json(name): Json<String>,
) -> Result<Json<String>, StatusCode> {
    sqlx::query("INSERT INTO ledgers (name) VALUES (?) ON DUPLICATE KEY UPDATE name = name")
        .bind(&name)
        .execute(&state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    broadcast_sync_event(&state, "ledger", "created", Some(name.clone()));

    Ok(Json(name))
}

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

    sqlx::query("UPDATE records SET ledger = ? WHERE ledger = ?")
        .bind(&new_name)
        .bind(&old_name)
        .execute(&state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    broadcast_sync_event(&state, "ledger", "updated", Some(new_name.clone()));

    Ok(Json(new_name))
}

async fn delete_ledger(
    State(state): State<Arc<AppState>>,
    Path(name): Path<String>,
) -> Result<StatusCode, StatusCode> {
    sqlx::query("DELETE FROM ledgers WHERE name = ?")
        .bind(&name)
        .execute(&state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    broadcast_sync_event(&state, "ledger", "deleted", Some(name));

    Ok(StatusCode::NO_CONTENT)
}

async fn get_all_staff(State(state): State<Arc<AppState>>) -> Result<Json<Vec<Staff>>, StatusCode> {
    let staff = get_all_staff_from_db(&state.db, None).await?;
    Ok(Json(staff))
}

async fn get_all_staff_from_db(db: &MySqlPool, since: Option<DateTime<Utc>>) -> Result<Vec<Staff>, StatusCode> {
    let query = if let Some(since) = since {
        sqlx::query(
            "SELECT id, name, updated_at FROM staff WHERE updated_at > ? AND deleted_at IS NULL ORDER BY name"
        ).bind(since)
    } else {
        sqlx::query("SELECT id, name, updated_at FROM staff WHERE deleted_at IS NULL ORDER BY name")
    };

    let rows = query
        .fetch_all(db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let staff = rows
        .into_iter()
        .map(|row| {
            let updated_at: Option<DateTime<Utc>> = row.get("updated_at");
            Staff {
                id: row.get::<i32, _>("id").to_string(),
                name: row.get("name"),
                updated_at: updated_at.map(|dt| dt.to_rfc3339()),
            }
        })
        .collect();

    Ok(staff)
}

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
        updated_at: Some(Utc::now().to_rfc3339()),
    };

    broadcast_sync_event(&state, "staff", "created", Some(staff.id.clone()));

    Ok(Json(staff))
}

async fn update_staff(
    State(state): State<Arc<AppState>>,
    Path(id): Path<String>,
    Json(req): Json<UpdateStaffRequest>,
) -> Result<Json<Staff>, StatusCode> {
    let id_i32: i32 = id.parse().map_err(|_| StatusCode::BAD_REQUEST)?;

    sqlx::query("UPDATE staff SET name = ? WHERE id = ?")
        .bind(&req.name)
        .bind(id_i32)
        .execute(&state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let staff = Staff {
        id: id.clone(),
        name: req.name,
        updated_at: Some(Utc::now().to_rfc3339()),
    };

    broadcast_sync_event(&state, "staff", "updated", Some(id));

    Ok(Json(staff))
}

async fn delete_staff(
    State(state): State<Arc<AppState>>,
    Path(id): Path<String>,
) -> Result<StatusCode, StatusCode> {
    let id_i32: i32 = id.parse().map_err(|_| StatusCode::BAD_REQUEST)?;

    let result = sqlx::query("UPDATE staff SET deleted_at = NOW() WHERE id = ? AND deleted_at IS NULL")
        .bind(id_i32)
        .execute(&state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    if result.rows_affected() == 0 {
        return Err(StatusCode::NOT_FOUND);
    }

    broadcast_sync_event(&state, "staff", "deleted", Some(id));

    Ok(StatusCode::NO_CONTENT)
}

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

    let contents = rows.into_iter().map(|row| row.get("work_content")).collect();
    Ok(Json(contents))
}

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

    let categories = rows.into_iter().map(|row| row.get("category")).collect();
    Ok(Json(categories))
}