#!/usr/bin/env bash
set -uo pipefail

if [[ ! -f pubspec.yaml || ! -d test ]]; then
  echo 'ERROR: Ejecuta este script desde la carpeta lagun_mobile, que contiene pubspec.yaml y test/.' >&2
  exit 2
fi

STAMP="$(date '+%Y%m%d_%H%M%S')"
OUT="evidencias_practica11/$STAMP"
mkdir -p "$OUT"

{
  echo "Fecha local: $(date '+%Y-%m-%d %H:%M:%S %Z %z')"
  echo "Fecha UTC: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "Proyecto: $(pwd)"
  echo "Git commit: $(git rev-parse --short HEAD 2>/dev/null || echo 'no disponible')"
  echo "Git rama: $(git branch --show-current 2>/dev/null || echo 'no disponible')"
  echo "Versión aplicación (pubspec.yaml): $(grep -m1 '^version:' pubspec.yaml | sed 's/^version:[[:space:]]*//' || true)"
  echo "Sistema host: $(uname -srm)"
  if command -v sw_vers >/dev/null 2>&1; then
    echo "macOS: $(sw_vers -productVersion)"
  fi
  echo
  echo 'Flutter:'
  flutter --version 2>&1 || true
  echo
  echo 'Dispositivos Flutter:'
  flutter devices 2>&1 || true
  echo
  echo 'Android conectado (si existe):'
  if command -v adb >/dev/null 2>&1; then
    adb devices -l 2>&1 || true
    echo "Modelo Android: $(adb shell getprop ro.product.model 2>/dev/null | tr -d '\r' || true)"
    echo "Versión Android: $(adb shell getprop ro.build.version.release 2>/dev/null | tr -d '\r' || true)"
    echo "API Android: $(adb shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r' || true)"
  else
    echo 'adb no disponible en PATH'
  fi
  echo
  echo 'Servidor: Supabase (registrar proyecto/región y entorno de manera manual; NO incluir claves o tokens)'
  echo 'Tipo de ejecución: flutter test en host (no equivale a pruebas E2E en emulador)'
} > "$OUT/entorno.txt"

printf 'Archivo de entorno: %s\n' "$OUT/entorno.txt"

set +e
flutter test --coverage --reporter expanded > "$OUT/pruebas.log" 2>&1
TEST_CODE=$?
flutter analyze > "$OUT/analisis.log" 2>&1
ANALYZE_CODE=$?
set -e

if [[ -f coverage/lcov.info ]]; then
  cp coverage/lcov.info "$OUT/lcov.info"
  awk -F: '/^LF:/{total+=$2} /^LH:/{hit+=$2} END { if(total>0) printf "Cobertura por líneas LCOV: %d/%d (%.2f%%)\n",hit,total,100*hit/total; else print "Sin líneas de cobertura medibles" }' "$OUT/lcov.info" > "$OUT/resumen_cobertura.txt"
else
  echo 'No se generó coverage/lcov.info' > "$OUT/resumen_cobertura.txt"
fi

{
  echo "Fecha de ejecución: $(date '+%Y-%m-%d %H:%M:%S %Z %z')"
  echo "Comando pruebas: flutter test --coverage --reporter expanded"
  echo "Código de salida pruebas: $TEST_CODE"
  echo "Comando análisis: flutter analyze"
  echo "Código de salida análisis: $ANALYZE_CODE"
  echo
  cat "$OUT/resumen_cobertura.txt"
  echo
  echo 'Últimas líneas de las pruebas:'
  tail -n 25 "$OUT/pruebas.log"
  echo
  echo 'Últimas líneas del análisis:'
  tail -n 12 "$OUT/analisis.log"
} > "$OUT/resumen.txt"

cat "$OUT/resumen.txt"
echo
printf 'EVIDENCIAS GUARDADAS EN: %s\n' "$OUT"
exit "$TEST_CODE"
