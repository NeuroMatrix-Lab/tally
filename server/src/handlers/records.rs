use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    routing::get,
    Json, Router,
};
use chrono::{DateTime, Utc};
use sqlx::{MySqlPool, Row};
use std::{collections::HashMap, sync::Arc};

use crate::{
    db::{get_all_records_from_db, row_to_record},
    models::*,
    state::{broadcast_sync_event, AppState},
};

pub fn router() -> Router<Arc<AppState>> {
    Router::new()
        .route("/", get(get_all_records).post(create_record))
        .route("/recent", get(get_recent_records))
        .route("/search", axum::routing::post(search_records))
        .route("/deleted", get(get_deleted_records))
        .route("/{id}", axum::routing::put(update_record).delete(delete_record))
        .route("/{id}/restore", axum::routing::post(restore_record))
        .route("/{id}/permanent", axum::routing::delete(permanently_delete_record))
}

async fn get_all_records(State(state): State<Arc<AppState>>) -> Result<Json<Vec<Record>>, StatusCode> {
    let records = get_all_records_from_db(&state.db).await?;
    Ok(Json(records))
}

async fn get_recent_records(
    State(state): State<Arc<AppState>>,
    Query(params): Query<HashMap<String, String>>,
) -> Result<Json<Vec<Record>>, StatusCode> {
    let months: i32 = params
        .get("months")
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
        "#,
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
        "#,
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

    let mut sql_query = sqlx::query(sqlx::AssertSqlSafe(query))
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
    println!(
        "[debug] create_record: id={}, category={}, amount={}, ledger={}",
        req.id, req.category, req.amount, req.ledger
    );

    let date = DateTime::parse_from_rfc3339(&req.date)
        .map_err(|_| StatusCode::BAD_REQUEST)?
        .with_timezone(&Utc);

    let staff_ids_json =
        serde_json::to_string(&req.staff_ids).map_err(|_| StatusCode::BAD_REQUEST)?;

    sqlx::query(
        r#"
        INSERT INTO records (record_id, date, category, work_content, amount, ledger, image_url, staff_ids)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        "#,
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

    broadcast_sync_event(&state, "record", "created", Some(req.id.clone()));
    println!("[debug] record created successfully: id={}", req.id);

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

    let staff_ids_json =
        serde_json::to_string(&req.staff_ids).map_err(|_| StatusCode::BAD_REQUEST)?;

    sqlx::query(
        r#"
        UPDATE records
        SET date = ?, category = ?, work_content = ?, amount = ?, ledger = ?, image_url = ?, staff_ids = ?
        WHERE record_id = ? AND deleted_at IS NULL
        "#,
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

    broadcast_sync_event(&state, "record", "updated", Some(id.clone()));
    println!("[debug] record updated successfully: id={}", id);

    Ok(Json(record))
}

async fn delete_record(
    State(state): State<Arc<AppState>>,
    Path(id): Path<String>,
) -> Result<StatusCode, StatusCode> {
    println!("[debug] delete_record requested: id={}", id);

    let result =
        sqlx::query("UPDATE records SET deleted_at = NOW() WHERE record_id = ? AND deleted_at IS NULL")
            .bind(&id)
            .execute(&state.db)
            .await
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    if result.rows_affected() == 0 {
        return Err(StatusCode::NOT_FOUND);
    }

    broadcast_sync_event(&state, "record", "deleted", Some(id.clone()));
    println!("[debug] record deleted: id={}", id);

    Ok(StatusCode::NO_CONTENT)
}

async fn get_deleted_records(
    State(state): State<Arc<AppState>>,
) -> Result<Json<Vec<Record>>, StatusCode> {
    let rows = sqlx::query(
        r#"
        SELECT
            record_id, date, category, work_content, amount, ledger, image_url, staff_ids, updated_at, deleted_at
        FROM records
        WHERE deleted_at IS NOT NULL
        ORDER BY deleted_at DESC
        "#,
    )
    .fetch_all(&state.db)
    .await
    .map_err(|e| {
        tracing::error!("get_deleted_records query failed: {:?}", e);
        StatusCode::INTERNAL_SERVER_ERROR
    })?;

    let records = rows.into_iter().map(row_to_record).collect();
    Ok(Json(records))
}

async fn restore_record(
    State(state): State<Arc<AppState>>,
    Path(id): Path<String>,
) -> Result<StatusCode, StatusCode> {
    println!("[debug] restore_record requested: id={}", id);

    let result =
        sqlx::query("UPDATE records SET deleted_at = NULL WHERE record_id = ? AND deleted_at IS NOT NULL")
            .bind(&id)
            .execute(&state.db)
            .await
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    if result.rows_affected() == 0 {
        return Err(StatusCode::NOT_FOUND);
    }

    broadcast_sync_event(&state, "record", "restored", Some(id.clone()));
    println!("[debug] record restored: id={}", id);

    Ok(StatusCode::NO_CONTENT)
}

async fn permanently_delete_record(
    State(state): State<Arc<AppState>>,
    Path(id): Path<String>,
) -> Result<StatusCode, StatusCode> {
    println!("[debug] permanently_delete_record requested: id={}", id);

    let result =
        sqlx::query("DELETE FROM records WHERE record_id = ? AND deleted_at IS NOT NULL")
            .bind(&id)
            .execute(&state.db)
            .await
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    if result.rows_affected() == 0 {
        return Err(StatusCode::NOT_FOUND);
    }

    println!("[debug] permanent record deletion complete: id={}", id);
    Ok(StatusCode::NO_CONTENT)
}

// incremental_sync needs shared helpers; keep query-level helpers in this module for reuse
pub async fn query_records_since(
    db: &MySqlPool,
    since: DateTime<Utc>,
) -> Result<(Vec<Record>, Vec<String>), StatusCode> {
    let records = sqlx::query(
        r#"
        SELECT record_id, date, category, work_content, amount, ledger, image_url, staff_ids, updated_at, deleted_at
        FROM records
        WHERE updated_at >= ?
        ORDER BY updated_at DESC
        "#,
    )
    .bind(since)
    .fetch_all(db)
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

    Ok((active_records, deleted_ids))
}

pub async fn query_deleted_staff_ids_since(
    db: &MySqlPool,
    since: DateTime<Utc>,
) -> Result<Vec<String>, StatusCode> {
    let rows = sqlx::query(
        "SELECT id FROM staff WHERE deleted_at >= ? AND deleted_at IS NOT NULL",
    )
    .bind(since)
    .fetch_all(db)
    .await
    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(rows
        .into_iter()
        .map(|row| row.get::<i32, _>("id").to_string())
        .collect())
}

