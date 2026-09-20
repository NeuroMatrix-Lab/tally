use axum::{
    extract::{
        ws::{Message, WebSocket, WebSocketUpgrade},
        State,
    },
    response::IntoResponse,
};
use futures_util::{SinkExt, StreamExt};
use std::sync::Arc;

use crate::state::AppState;

pub async fn ws_handler(ws: WebSocketUpgrade, State(state): State<Arc<AppState>>) -> impl IntoResponse {
    ws.on_upgrade(move |socket| handle_socket(socket, state))
}

async fn handle_socket(socket: WebSocket, state: Arc<AppState>) {
    let mut rx = state.tx.subscribe();

    tracing::info!("New WebSocket client connected");

    let (mut sender, mut receiver) = socket.split();
    let (pong_tx, mut pong_rx) = tokio::sync::mpsc::channel::<()>(4);

    let mut send_task = tokio::spawn(async move {
        loop {
            tokio::select! {
                Ok(msg) = rx.recv() => {
                    let msg_str = match serde_json::to_string(&msg) {
                        Ok(s) => s,
                        Err(err) => {
                            tracing::error!("failed to serialize sync message: {err}");
                            continue;
                        }
                    };
                    if sender.send(Message::Text(msg_str.into())).await.is_err() {
                        break;
                    }
                }
                Some(_) = pong_rx.recv() => {
                    if sender.send(Message::Text("{\"type\":\"pong\"}".into())).await.is_err() {
                        break;
                    }
                }
                else => break,
            }
        }
    });

    let mut recv_task = tokio::spawn(async move {
        while let Some(Ok(msg)) = receiver.next().await {
            match msg {
                Message::Text(text) => {
                    // 客户端心跳，避免 Cloudflare 等代理空闲断连
                    if text.contains("ping") {
                        let _ = pong_tx.send(()).await;
                        continue;
                    }
                    tracing::info!("Received message from client: {}", text);
                }
                Message::Ping(_) | Message::Pong(_) => {}
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

    tracing::info!("WebSocket client disconnected");
}
