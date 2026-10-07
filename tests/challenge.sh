#!/usr/bin/env bash
# Pemeriksaan baca-saja Lab 04. Tidak membuat, menghentikan, atau menghapus container.
set -u

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SITE_DIR="$ROOT/site"
SITE_NAME="${LAB04_SITE_NAME:-cloudlab-site}"
CANARY_NAME="${LAB04_CANARY_NAME:-cloudlab-canary}"
SITE_PORT="${LAB04_SITE_PORT:-8088}"
CANARY_PORT="${LAB04_CANARY_PORT:-8089}"
PASS_COUNT=0
FAIL_COUNT=0

pass() { printf 'PASS %s\n' "$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { printf 'FAIL %s\n     -> %s\n' "$1" "$2"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  fail 'Docker Engine tersedia' 'Jalankan Docker Desktop/Engine, lalu cek docker version.'
  printf '\nChallenge: %d PASS, %d FAIL\n' "$PASS_COUNT" "$FAIL_COUNT"
  exit 1
fi

for image in nginx:alpine python:3.12-alpine node:22-alpine; do
  if docker image inspect "$image" >/dev/null 2>&1; then
    pass "A image $image tersedia"
  else
    fail "A image $image tersedia" "Jalankan docker pull $image."
  fi
done

site_state="$(docker inspect --format '{{.State.Running}}|{{.Config.Image}}' "$SITE_NAME" 2>/dev/null || true)"
if [[ "$site_state" == 'true|nginx:alpine' ]]; then
  pass "B $SITE_NAME berjalan dari nginx:alpine"
else
  fail "B $SITE_NAME berjalan dari nginx:alpine" "Jalankan Nginx dengan --name $SITE_NAME; cek docker ps -a dan docker logs $SITE_NAME."
fi

site_binding="$(docker port "$SITE_NAME" 80/tcp 2>/dev/null || true)"
if [[ "$site_binding" == "127.0.0.1:$SITE_PORT" ]]; then
  pass "B port $SITE_PORT hanya di 127.0.0.1"
else
  fail "B port $SITE_PORT hanya di 127.0.0.1" "Gunakan -p 127.0.0.1:$SITE_PORT:80; cek docker port $SITE_NAME."
fi

mount_info="$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/usr/share/nginx/html"}}{{.Type}}|{{.Source}}|{{.RW}}{{end}}{{end}}' "$SITE_NAME" 2>/dev/null || true)"
IFS='|' read -r mount_type mount_source mount_rw <<< "$mount_info"
expected_site="$(cd "$SITE_DIR" && pwd -P)"
source_normal="${mount_source//\\//}"
expected_normal="${expected_site//\\//}"
source_normal="${source_normal%/}"
expected_normal="${expected_normal%/}"
source_lower="${source_normal,,}"
expected_lower="${expected_normal,,}"
site_source_matches=0
[[ "$source_lower" == "$expected_lower" ]] && site_source_matches=1
if command -v wslpath >/dev/null 2>&1; then
  expected_win="$(wslpath -w "$expected_site" 2>/dev/null || true)"
  expected_win="${expected_win//\\//}"
  [[ "$source_lower" == "${expected_win,,}" ]] && site_source_matches=1
elif command -v cygpath >/dev/null 2>&1; then
  expected_win="$(cygpath -w "$expected_site" 2>/dev/null || true)"
  expected_win="${expected_win//\\//}"
  [[ "$source_lower" == "${expected_win,,}" ]] && site_source_matches=1
fi
if [[ "$mount_type" == bind && "$mount_rw" == false && "$site_source_matches" -eq 1 ]]; then
  pass 'B folder site/ di-bind mount read-only'
else
  fail 'B folder site/ di-bind mount read-only' "Jalankan dari root repo dengan --mount type=bind,source=<path site>,target=/usr/share/nginx/html,readonly; cek docker inspect $SITE_NAME."
fi

site_code='000'
site_body=''
if command -v curl >/dev/null 2>&1; then
  site_code="$(curl -sS --max-time 5 -o /dev/null -w '%{http_code}' "http://127.0.0.1:$SITE_PORT/" 2>/dev/null || true)"
  site_body="$(curl -fsS --max-time 5 "http://127.0.0.1:$SITE_PORT/" 2>/dev/null || true)"
fi
if [[ "$site_code" == 200 ]]; then
  pass "C halaman utama HTTP 200 di $SITE_PORT"
else
  fail "C halaman utama HTTP 200 di $SITE_PORT" "Buka http://127.0.0.1:$SITE_PORT/; cek docker logs $SITE_NAME."
fi
if [[ "$site_body" == *'INCIDENT-042: Pemeliharaan selesai'* ]]; then
  pass 'D halaman menampilkan INCIDENT-042: Pemeliharaan selesai'
else
  fail 'D halaman menampilkan INCIDENT-042: Pemeliharaan selesai' 'Ganti literal STATUS_OK: Layanan normal di site/index.html, simpan, lalu muat ulang.'
fi
if [[ "$site_body" != *'STATUS_OK: Layanan normal'* && -n "$site_body" ]]; then
  pass 'D status lama sudah diganti'
else
  fail 'D status lama sudah diganti' 'Pastikan halaman tidak lagi menampilkan STATUS_OK: Layanan normal.'
fi

canary_state="$(docker inspect --format '{{.State.Running}}|{{.Config.Image}}' "$CANARY_NAME" 2>/dev/null || true)"
if [[ "$canary_state" == 'true|nginx:alpine' ]]; then
  pass "E $CANARY_NAME berjalan dari nginx:alpine"
else
  fail "E $CANARY_NAME berjalan dari nginx:alpine" "Jalankan container kedua dengan --name $CANARY_NAME, tanpa menghentikan $SITE_NAME."
fi

canary_binding="$(docker port "$CANARY_NAME" 80/tcp 2>/dev/null || true)"
if [[ "$canary_binding" == "127.0.0.1:$CANARY_PORT" ]]; then
  pass "E port $CANARY_PORT hanya di 127.0.0.1"
else
  fail "E port $CANARY_PORT hanya di 127.0.0.1" "Gunakan -p 127.0.0.1:$CANARY_PORT:80."
fi

canary_code='000'
if command -v curl >/dev/null 2>&1; then
  canary_code="$(curl -sS --max-time 5 -o /dev/null -w '%{http_code}' "http://127.0.0.1:$CANARY_PORT/" 2>/dev/null || true)"
fi
if [[ "$canary_code" == 200 ]]; then
  pass "E canary HTTP 200 di $CANARY_PORT"
else
  fail "E canary HTTP 200 di $CANARY_PORT" "Cek docker logs $CANARY_NAME dan http://127.0.0.1:$CANARY_PORT/."
fi

site_ports="$(docker port "$SITE_NAME" 2>/dev/null || true)"
if [[ "$site_ports" == "80/tcp -> 127.0.0.1:$SITE_PORT" ]]; then
  pass "E $SITE_NAME tidak membuka port host lain"
else
  fail "E $SITE_NAME tidak membuka port host lain" "Cek docker port $SITE_NAME; terbitkan hanya 127.0.0.1:$SITE_PORT:80."
fi

canary_ports="$(docker port "$CANARY_NAME" 2>/dev/null || true)"
if [[ "$canary_ports" == "80/tcp -> 127.0.0.1:$CANARY_PORT" ]]; then
  pass "E $CANARY_NAME tidak membuka port host lain"
else
  fail "E $CANARY_NAME tidak membuka port host lain" "Cek docker port $CANARY_NAME; terbitkan hanya 127.0.0.1:$CANARY_PORT:80."
fi

printf '\nChallenge: %d PASS, %d FAIL\n' "$PASS_COUNT" "$FAIL_COUNT"
(( FAIL_COUNT == 0 ))
