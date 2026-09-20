use std::sync::Arc;

use chrono::{DateTime, Utc};
use sqlx::MySqlPool;
use tokio::sync::broadcast;

use crate::models::SyncMessage;

#[derive(Clone)]
pub struct AppState {
    pub db: MySqlPool,
    pub request_count: Arc<std::sync::atomic::AtomicU64>,
    pub tx: broadcast::Sender<SyncMessage>,
    /// 空字符串表示未启用鉴权
    pub api_password: String,
}

pub fn broadcast_sync_event(
    state: &Arc<AppState>,
    entity_type: &str,
    event_type: &str,
    entity_id: Option<String>,
) {
    let msg = SyncMessage {
        event_type: event_type.to_string(),
        entity_type: entity_type.to_string(),
        entity_id,
        timestamp: Utc::now(),
    };

    let _ = state.tx.send(msg);
    tracing::info!("Broadcasted {} event for {}", event_type, entity_type);
}
