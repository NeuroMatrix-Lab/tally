use axum::{extract::State, http::StatusCode, routing::get, Json, Router};
use sqlx::Row;
use std::sync::Arc;

use crate::state::AppState;

pub fn router() -> Router<Arc<AppState>> {
    Router::new()
        .route("/work-contents", get(get_work_contents))
        .route("/categories", get(get_categories))
}

async fn get_work_contents(
    State(state): State<Arc<AppState>>,
) -> Result<Json<Vec<String>>, StatusCode> {
    let rows = sqlx::query(
        r#"
        SELECT DISTINCT work_content FROM records
        WHERE deleted_at IS NULL
        ORDER BY work_content
        "#,
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
        "#,
    )
    .fetch_all(&state.db)
    .await
    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let categories = rows.into_iter().map(|row| row.get("category")).collect();
    Ok(Json(categories))
}
