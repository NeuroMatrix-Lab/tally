use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SyncMessage {
    pub event_type: String,
    pub entity_type: String,
    pub entity_id: Option<String>,
    pub timestamp: DateTime<Utc>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Record {
    pub id: String,
    #[serde(rename = "recordId")]
    pub record_id: String,
    pub date: String,
    pub category: String,
    #[serde(rename = "workContent")]
    pub work_content: String,
    pub amount: f64,
    pub ledger: String,
    #[serde(rename = "imageUrl")]
    pub image_url: Option<String>,
    #[serde(rename = "staffIds")]
    pub staff_ids: Vec<String>,
    #[serde(rename = "updatedAt")]
    pub updated_at: Option<String>,
    #[serde(rename = "deletedAt")]
    pub deleted_at: Option<String>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Staff {
    pub id: String,
    pub name: String,
    #[serde(rename = "updatedAt")]
    pub updated_at: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct CreateRecordRequest {
    pub id: String,
    pub date: String,
    pub category: String,
    #[serde(rename = "workContent")]
    pub work_content: String,
    pub amount: f64,
    pub ledger: String,
    #[serde(rename = "imageUrl")]
    pub image_url: Option<String>,
    #[serde(rename = "staffIds")]
    pub staff_ids: Vec<String>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateRecordRequest {
    pub date: String,
    pub category: String,
    #[serde(rename = "workContent")]
    pub work_content: String,
    pub amount: f64,
    pub ledger: String,
    #[serde(rename = "imageUrl")]
    pub image_url: Option<String>,
    #[serde(rename = "staffIds")]
    pub staff_ids: Vec<String>,
}

#[derive(Debug, Deserialize)]
pub struct CreateStaffRequest {
    pub name: String,
}

#[derive(Debug, Deserialize)]
pub struct UpdateStaffRequest {
    pub name: String,
}

#[derive(Debug, Deserialize)]
pub struct SearchRecordsRequest {
    #[serde(rename = "startDate")]
    pub start_date: String,
    #[serde(rename = "endDate")]
    pub end_date: String,
    pub category: Option<String>,
    pub ledger: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct IncrementalSyncRequest {
    #[serde(rename = "lastSyncTime")]
    pub last_sync_time: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct IncrementalSyncResponse {
    pub records: Vec<Record>,
    pub staff: Vec<Staff>,
    pub ledgers: Vec<String>,
    #[serde(rename = "deletedRecordIds")]
    pub deleted_record_ids: Vec<String>,
    #[serde(rename = "deletedStaffIds")]
    pub deleted_staff_ids: Vec<String>,
    #[serde(rename = "serverTime")]
    pub server_time: String,
}
