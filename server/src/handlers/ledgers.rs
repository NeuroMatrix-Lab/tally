use axum::{
    extract::{Path, State},
    http::StatusCode,
    routing::get,
    Json, Router,
};
use std::sync::Arc;

use crate::{
    db::get_all_ledgers_from_db,
    state::{broadcast_sync_event, AppState},
};

pub fn router() -> Router<Arc<AppState>> {
    Router::new()
        .route("/", get(get_all_ledgers).post(create_ledger))
        .route("/{name}", axum::routing::put(update_ledger).delete(delete_ledger))
}

async fn get_all_ledgers(State(state): State<Arc<AppState>>) -> Result<Json<Vec<String>>, StatusCode> {
    let ledgers = get_all_ledgers_from_db(&state.db).await?;
    Ok(Json(ledgers))
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
