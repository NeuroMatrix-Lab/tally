use axum::{extract::State, http::StatusCode, Json};
use sqlx::Row;
use std::sync::Arc;

use crate::state::AppState;

pub async fn auth_check(State(state): State<Arc<AppState>>) -> Json<serde_json::Value> {
    Json(serde_json::json!({
        "authRequired": !state.api_password.is_empty(),
        "status": "ok"
    }))
}

pub async fn health_check(
    State(state): State<Arc<AppState>>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let request_count = state
        .request_count
        .load(std::sync::atomic::Ordering::Relaxed);

    match sqlx::query("SELECT 1").fetch_one(&state.db).await {
        Ok(_) => {
            tracing::info!("Health check passed");
            Ok(Json(serde_json::json!({
                "status": "healthy",
                "database": "connected",
                "uptime": "running",
                "requestCount": request_count
            })))
        }
        Err(e) => {
            tracing::error!("Health check failed: {:?}", e);
            Err(StatusCode::SERVICE_UNAVAILABLE)
        }
    }
}

pub async fn get_metrics(
    State(state): State<Arc<AppState>>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let request_count = state
        .request_count
        .load(std::sync::atomic::Ordering::Relaxed);

    let db_stats =
        sqlx::query("SELECT COUNT(*) as count FROM records WHERE deleted_at IS NULL")
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
        "version": "1.1.4"
    })))
}
