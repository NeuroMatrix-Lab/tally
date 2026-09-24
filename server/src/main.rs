mod auth;
mod config;
mod db;
mod handlers;
mod models;
mod state;

use std::sync::Arc;

use anyhow::Result;
use axum::{
    middleware,
    routing::{get, post},
    Router,
};
use sqlx::mysql::MySqlPoolOptions;
use tokio::sync::broadcast;
use tower_http::compression::CompressionLayer;
use tower_http::cors::{Any, CorsLayer};
use tower_http::trace::TraceLayer;
use tracing::{info, Level};
use tracing_subscriber::FmtSubscriber;

use auth::auth_middleware;
use config::Config;
use models::SyncMessage;
use state::AppState;

#[tokio::main]
async fn main() -> Result<()> {
    FmtSubscriber::builder()
        .with_max_level(Level::INFO)
        .with_target(false)
        .with_thread_ids(true)
        .with_file(true)
        .with_line_number(true)
        .json()
        .init();

    let config = Config::load();
    info!("Starting Tally Server with WebSocket Sync...");
    println!(
        "[debug] starting tally server on port {}",
        config.server.port
    );

    let database_url = config.database_url();
    println!(
        "[debug] connecting to database at {}:{}/{}...",
        config.database.host, config.database.port, config.database.name
    );
    println!("[debug] database_url={}", database_url);

    let pool = MySqlPoolOptions::new()
        .max_connections(5)
        .after_connect(|connection, _| {
            Box::pin(async move {
                sqlx::query("SET time_zone = '+08:00'")
                    .execute(connection)
                    .await?;
                Ok(())
            })
        })
        .connect(&database_url)
        .await?;

    info!("Database connected successfully!");

    db::init_database(&pool).await?;

    let (tx, _rx) = broadcast::channel::<SyncMessage>(100);
    println!("[debug] websocket broadcast channel initialized");

    let state = Arc::new(AppState {
        db: pool,
        request_count: Arc::new(std::sync::atomic::AtomicU64::new(0)),
        tx,
        api_password: config.server.password.clone(),
    });

    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    let app = Router::new()
        .route("/api/v1/health", get(handlers::system::health_check))
        .route("/api/v1/auth", get(handlers::system::auth_check))
        .route("/api/v1/metrics", get(handlers::system::get_metrics))
        .route("/api/v1/ws", get(handlers::ws::ws_handler))
        .route("/api/v1/sync", post(handlers::sync::incremental_sync))
        .nest("/api/v1/records", handlers::records::router())
        .nest("/api/v1/ledgers", handlers::ledgers::router())
        .nest("/api/v1/staff", handlers::staff::router())
        .nest("/api/v1", handlers::meta::router())
        .layer(middleware::from_fn_with_state(state.clone(), auth_middleware))
        .layer(cors)
        .layer(CompressionLayer::new())
        .layer(TraceLayer::new_for_http())
        .with_state(state);

    let addr = format!("0.0.0.0:{}", config.server.port);

    info!("Server listening on {}", addr);
    println!("[debug] bind address={}", addr);
    let listener = tokio::net::TcpListener::bind(&addr).await?;

    axum::serve(listener, app).await?;

    Ok(())
}
