use axum::{extract::State, http::StatusCode, Json};
use chrono::{DateTime, Timelike, Utc};
use std::sync::Arc;

use crate::{
    db::{get_all_ledgers_from_db, get_all_records_from_db, get_all_staff_from_db},
    handlers::records::{query_deleted_staff_ids_since, query_records_since},
    models::{IncrementalSyncRequest, IncrementalSyncResponse},
    state::AppState,
};

pub async fn incremental_sync(
    State(state): State<Arc<AppState>>,
    Json(req): Json<IncrementalSyncRequest>,
) -> Result<Json<IncrementalSyncResponse>, StatusCode> {
    println!(
        "[debug] incremental_sync request received: last_sync_time={:?}",
        req.last_sync_time
    );

    // MySQL TIMESTAMP 秒级精度；截断到整秒并用 >=，避免同一秒内的变更被漏掉
    let last_sync_time = req
        .last_sync_time
        .and_then(|t| DateTime::parse_from_rfc3339(&t).ok())
        .map(|dt| dt.with_timezone(&Utc))
        .map(|dt| dt.with_nanosecond(0).unwrap_or(dt));

    let server_time = Utc::now();

    let (records, deleted_record_ids) = if let Some(since) = last_sync_time {
        query_records_since(&state.db, since).await?
    } else {
        let records = get_all_records_from_db(&state.db).await?;
        (records, Vec::new())
    };

    let staff = get_all_staff_from_db(&state.db, last_sync_time).await?;
    let ledgers = get_all_ledgers_from_db(&state.db).await?;

    println!(
        "[debug] incremental_sync summary: records={}, staff={}, ledgers={}, deleted_records={}",
        records.len(),
        staff.len(),
        ledgers.len(),
        deleted_record_ids.len(),
    );

    let deleted_staff_ids = if let Some(since) = last_sync_time {
        query_deleted_staff_ids_since(&state.db, since).await?
    } else {
        Vec::new()
    };

    let response = IncrementalSyncResponse {
        records,
        staff,
        ledgers,
        deleted_record_ids,
        deleted_staff_ids,
        server_time: server_time.to_rfc3339(),
    };

    println!(
        "[debug] incremental_sync response ready: server_time={}",
        response.server_time
    );
    Ok(Json(response))
}
