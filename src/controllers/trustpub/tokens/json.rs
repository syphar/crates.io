use axum::Json;
use axum::extract::FromRequest;
use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize, FromRequest, utoipa::ToSchema)]
#[from_request(via(Json))]
pub struct ExchangeRequest {
    pub jwt: String,
}

#[derive(Debug, Serialize, utoipa::ToSchema)]
pub struct ExchangeResponse {
    pub token: String,
}
