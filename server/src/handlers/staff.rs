use axum::{
    extract::{Path, State},
    http::StatusCode,
    routing::get,
    Json, Router,
};
use chrono::Utc;
use std::sync::Arc;

use crate::{
    db::get_all_staff_from_db,
    models::{CreateStaffRequest, Staff, UpdateStaffRequest},
    state::{broadcast_sync_event, AppState},
};

pub fn router() -> Router<Arc<AppState>> {
    Router::new()
        .route("/", get(get_all_staff).post(create_staff))
        .route("/{id}", axum::routing::put(update_staff).delete(delete_staff))
}

async fn get_all_staff(State(state): State<Arc<AppState>>) -> Result<Json<Vec<Staff>>, StatusCode> {
    let staff = get_all_staff_from_db(&state.db, None).await?;
    Ok(Json(staff))
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

    let result =
        sqlx::query("UPDATE staff SET deleted_at = NOW() WHERE id = ? AND deleted_at IS NULL")
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
