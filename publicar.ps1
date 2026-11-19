# Compila la app, asegura el service worker de limpieza y la publica.
flutter build web --release --wasm --pwa-strategy=none
if ($LASTEXITCODE -ne 0) { Write-Host "Error al compilar. No se publica." -ForegroundColor Red; exit 1 }

Copy-Item -Force "web/flutter_service_worker.js" "build/web/flutter_service_worker.js"

firebase deploy --only hosting