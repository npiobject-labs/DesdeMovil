use axum::{routing::get, Json, Router};
use serde_json::{json, Value};

const PUERTO: u16 = 8080;

/// Como se presenta el servicio. El nombre del proyecto lo inyecta `deploy.yml`
/// como secreto de Fly, igual que `BUILD_ID`; sin el, solo "backend". Asi `app/`
/// no lleva nunca el nombre de la plantilla y no hay nada que sustituir al clonarla.
fn descripcion() -> String {
    match std::env::var("PROYECTO").ok().filter(|v| !v.is_empty()) {
        Some(proyecto) => format!("{proyecto} backend"),
        None => "backend".to_string(),
    }
}

async fn raiz() -> String {
    descripcion()
}

async fn salud() -> Json<Value> {
    let build = std::env::var("BUILD_ID").unwrap_or_else(|_| "dev".to_string());
    Json(json!({ "ok": true, "build": build }))
}

#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/", get(raiz))
        .route("/salud", get(salud));

    let direccion = format!("0.0.0.0:{PUERTO}");
    let listener = tokio::net::TcpListener::bind(&direccion)
        .await
        .unwrap_or_else(|e| panic!("no se pudo abrir {direccion}: {e}"));

    println!("{} escuchando en {direccion}", descripcion());

    axum::serve(listener, app)
        .with_graceful_shutdown(async {
            let _ = tokio::signal::ctrl_c().await;
        })
        .await
        .expect("fallo del servidor HTTP");
}
