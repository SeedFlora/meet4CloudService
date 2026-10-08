#!/usr/bin/env bash
# Mulai/perbaiki situs Lab 04 dari lokasi script, bukan lokasi terminal.
set -euo pipefail

site_port=8088
container_name=cloudlab-site
repair=0
check_only=0
die() { printf 'STOP: %s\n' "$*" >&2; exit 1; }
usage() {
  printf 'bash scripts/start-lab04.sh [--repair] [--port 8088] [--name cloudlab-site] [--check-only]\n'
}
while (($#)); do
  case "$1" in
    --repair) repair=1; shift ;;
    --check-only) check_only=1; shift ;;
    --port) (($# >= 2)) || die '--port membutuhkan angka'; site_port="$2"; shift 2 ;;
    --name) (($# >= 2)) || die '--name membutuhkan nama'; container_name="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "Argumen tidak dikenal: $1" ;;
  esac
done
[[ "$site_port" =~ ^[0-9]{1,5}$ ]] || die 'Port harus angka 1..65535'
site_port=$((10#$site_port))
((site_port >= 1 && site_port <= 65535)) || die 'Port harus angka 1..65535'
[[ "$container_name" =~ ^cloudlab-[a-z0-9][a-z0-9_.-]*$ ]] || die 'Nama harus diawali cloudlab- dan memakai karakter nama container yang valid'
[[ "$container_name" != cloudlab-canary && "$container_name" != cloudlab-nginx ]] || die 'Nama canary/nginx pertama bukan target starter situs; gunakan cloudlab-site'

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "$script_dir/.." && pwd -P)"
index_file="$repo_root/site/index.html"
[[ -f "$index_file" && -s "$index_file" ]] || die "$index_file tidak ada/kosong. Pakai repo lengkap; jangan membuat site kosong."
site_dir="$(cd -- "$repo_root/site" && pwd -P)"
mount_source="$site_dir"
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    command -v cygpath >/dev/null 2>&1 || die 'cygpath tidak tersedia pada Git Bash'
    mount_source="$(cygpath -m "$site_dir")"
    ;;
esac
# Cegah Git Bash mengubah target /usr/share/nginx/html menjadi path Windows.
docker_cli() { MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' docker "$@"; }
mount_argument="type=bind,source=$mount_source,target=/usr/share/nginx/html,readonly"
printf 'REPO: %s\nHTML: %s\nMOUNT: %s\n' "$repo_root" "$index_file" "$mount_argument"
command -v docker >/dev/null 2>&1 || die 'Docker CLI belum tersedia'
engine="$(docker_cli info --format '{{.OSType}}')" || die 'Docker Engine belum siap'
[[ "$engine" == linux ]] || die 'Gunakan Docker Linux Engine'
if ((check_only)); then
  printf 'CHECK_OK: file dan Linux Engine siap; tidak ada container yang diubah.\n'
  exit 0
fi
command -v curl >/dev/null 2>&1 || die 'curl diperlukan untuk verifikasi HTTP'

names="$(docker_cli ps -a --format '{{.Names}}')"
conflicts=()
if printf '%s\n' "$names" | grep -Fxq -- "$container_name"; then
  conflicts+=("$container_name")
fi
if [[ "$container_name" == cloudlab-site ]] && printf '%s\n' "$names" | grep -Fxq cloudlab-nginx; then
  ports="$(docker_cli inspect --format '{{range (index .HostConfig.PortBindings "80/tcp")}}{{println .HostPort}}{{end}}' cloudlab-nginx)"
  if printf '%s\n' "$ports" | grep -Fxq -- "$site_port"; then
    conflicts+=(cloudlab-nginx)
  fi
fi
for name in "${conflicts[@]}"; do
  ((repair)) || die "Container $name sudah ada/memakai port. Gunakan --repair bila milik latihan Anda."
  image="$(docker_cli inspect --format '{{.Config.Image}}' "$name")"
  [[ "$image" =~ ^(docker\.io/library/)?nginx(:|@) ]] || die "$name memakai $image; tidak menghapus selain Nginx lab"
  if [[ "$name" != cloudlab-site && "$name" != cloudlab-nginx ]]; then
    lab_label="$(docker_cli inspect --format '{{index .Config.Labels "edu.cloud-services.lab"}}' "$name")"
    [[ "$lab_label" == 04 ]] || die "$name tidak mempunyai label starter Lab 04; container tetap dipertahankan"
  fi
done
if ! docker_cli image inspect nginx:alpine >/dev/null 2>&1; then
  printf 'Image belum tersedia; mengunduh nginx:alpine (memerlukan internet).\n'
  docker_cli pull nginx:alpine
fi
for name in "${conflicts[@]}"; do
  printf 'REPAIR: membuat ulang container lab %s; file host tetap ada.\n' "$name"
  docker_cli rm -f "$name"
done
docker_cli run --name "$container_name" -d -p "127.0.0.1:$site_port:80" \
  --label edu.cloud-services.lab=04 --mount "$mount_argument" nginx:alpine
http_code=000
for ((attempt=0; attempt<20; attempt++)); do
  http_code="$(curl -sS --max-time 2 -o /dev/null -w '%{http_code}' "http://127.0.0.1:$site_port/" 2>/dev/null)" || true
  [[ "$http_code" == 200 ]] && break
  sleep 0.25
done
[[ "$http_code" == 200 ]] || die "HTTP $http_code. Cek docker logs --tail 20 $container_name dan docker exec untuk isi mount."
docker_cli inspect --format '{{range .Mounts}}{{.Source}} -> {{.Destination}} RW={{.RW}}{{end}}' "$container_name"
printf 'HTTP %s OK\nWEB: http://127.0.0.1:%s/\nLanjutkan langkah lab dari root repo: %s\n' "$http_code" "$site_port" "$repo_root"
