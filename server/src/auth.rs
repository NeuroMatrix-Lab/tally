use axum::{
    extract::{Request, State},
    http::{HeaderMap, StatusCode, Uri},
    middleware::Next,
};
use std::sync::Arc;

use crate::state::AppState;

pub fn percent_decode(input: &str) -> String {
    let bytes = input.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'%' && i + 2 < bytes.len() {
            if let Ok(byte) = u8::from_str_radix(&input[i + 1..i + 3], 16) {
                out.push(byte);
                i += 3;
                continue;
            }
        }
        if bytes[i] == b'+' {
            out.push(b' ');
            i += 1;
            continue;
        }
        out.push(bytes[i]);
        i += 1;
    }
    String::from_utf8_lossy(&out).into_owned()
}

pub fn extract_api_password(headers: &HeaderMap, uri: &Uri) -> Option<String> {
    if let Some(value) = headers
        .get("x-api-password")
        .and_then(|v| v.to_str().ok())
        .filter(|v| !v.is_empty())
    {
        return Some(value.to_string());
    }

    if let Some(value) = headers
        .get("authorization")
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.strip_prefix("Bearer "))
        .filter(|v| !v.is_empty())
    {
        return Some(value.to_string());
    }

    if let Some(query) = uri.query() {
        for pair in query.split('&') {
            if let Some(value) = pair.strip_prefix("password=") {
                return Some(percent_decode(value));
            }
        }
    }

    None
}

pub async fn auth_middleware(
    State(state): State<Arc<AppState>>,
    request: Request,
    next: Next,
) -> Result<axum::response::Response, StatusCode> {
    if state.api_password.is_empty() {
        return Ok(next.run(request).await);
    }

    // 健康检查保持开放，便于连通性探测
    if request.uri().path() == "/api/v1/health" {
        return Ok(next.run(request).await);
    }

    let provided = extract_api_password(request.headers(), request.uri());
    match provided.as_deref() {
        Some(value) if value == state.api_password.as_str() => Ok(next.run(request).await),
        _ => Err(StatusCode::UNAUTHORIZED),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::http::{HeaderMap, HeaderValue, Uri};

    #[test]
    fn extracts_password_from_header() {
        let mut headers = HeaderMap::new();
        headers.insert("x-api-password", HeaderValue::from_static("secret"));
        let uri = Uri::from_static("/api/v1/records");
        assert_eq!(
            extract_api_password(&headers, &uri).as_deref(),
            Some("secret")
        );
    }

    #[test]
    fn extracts_password_from_bearer() {
        let mut headers = HeaderMap::new();
        headers.insert("authorization", HeaderValue::from_static("Bearer secret"));
        let uri = Uri::from_static("/api/v1/records");
        assert_eq!(
            extract_api_password(&headers, &uri).as_deref(),
            Some("secret")
        );
    }

    #[test]
    fn extracts_password_from_query() {
        let headers = HeaderMap::new();
        let uri = Uri::from_static("/api/v1/ws?password=secret");
        assert_eq!(
            extract_api_password(&headers, &uri).as_deref(),
            Some("secret")
        );
    }

    #[test]
    fn percent_decodes_password() {
        assert_eq!(percent_decode("a%20b"), "a b");
        assert_eq!(percent_decode("a+b"), "a b");
    }
}
