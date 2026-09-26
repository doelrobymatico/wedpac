#!/usr/bin/env bash
# Install or update Palet Pelaminan on a Linux VPS (Ubuntu, Debian, CentOS,
# OpenCloudOS, Rocky, ...). Run it as root:
#
#   curl -fsSL https://raw.githubusercontent.com/doelrobymatico/wedpac/claude/eager-ramanujan-v8dv01/deploy/install.sh | sudo bash
#
# To use another port (for example when 80/443 are taken by another site):
#
#   curl -fsSL https://raw.githubusercontent.com/doelrobymatico/wedpac/claude/eager-ramanujan-v8dv01/deploy/install.sh | sudo PORT=2001 bash
#
# Running it again pulls the latest code and restarts the app; the saved
# palette, password and port are kept.
#
# Optional settings (environment variables):
#   PORT            public port. 80 puts Caddy in front and allows HTTPS with a
#                   domain. Any other port serves the app directly over plain
#                   HTTP on http://<server-ip>:<port>.
#   DOMAIN          only with port 80, e.g. palet.example.com (its DNS A record
#                   must point to this VPS). Gives automatic HTTPS.
#   PALET_PASSWORD  login password (letters, digits, . _ - ; at least 6 characters)
#   BRANCH          git branch to deploy
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/doelrobymatico/wedpac.git}"
BRANCH="${BRANCH:-claude/eager-ramanujan-v8dv01}"
APP_DIR=/opt/palet-pelaminan
DATA_DIR=/var/lib/palet-pelaminan
ENV_FILE=/etc/palet-pelaminan.env
CADDY_DIR=/etc/caddy-palet
CADDY_BIN=/usr/local/bin/caddy-palet
NODE_VERSION=v20.18.1
NODE_BIN=/opt/node/bin/node
INTERNAL_PORT=8080

say()  { printf '\n\033[1;35m==> %s\033[0m\n' "$*"; }
die()  { printf '\n\033[1;31mGAGAL: %s\033[0m\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "Jalankan sebagai root (pakai sudo)."
command -v systemctl >/dev/null || die "systemd tidak ditemukan; skrip ini butuh systemd."

# Read answers from the terminal even when the script is piped into bash.
ask() { local prompt="$1" var=""; if [ -r /dev/tty ]; then read -r -p "$prompt" var </dev/tty || true; fi; printf '%s' "$var"; }

case "$(uname -m)" in
  x86_64|amd64)  NODE_ARCH=x64;   CADDY_ARCH=amd64 ;;
  aarch64|arm64) NODE_ARCH=arm64; CADDY_ARCH=arm64 ;;
  *) die "Arsitektur $(uname -m) belum didukung." ;;
esac

# ---- settings ---------------------------------------------------------------
OLD_PASSWORD=""; OLD_DOMAIN=""; OLD_PORT=""
if [ -f "$ENV_FILE" ]; then
  OLD_PASSWORD="$(sed -n 's/^PALET_PASSWORD=//p' "$ENV_FILE")"
  OLD_DOMAIN="$(sed -n 's/^# DOMAIN=//p' "$ENV_FILE")"
  OLD_PORT="$(sed -n 's/^# PUBLIC_PORT=//p' "$ENV_FILE")"
fi

PUBLIC_PORT="${PORT:-$OLD_PORT}"
if [ -z "$PUBLIC_PORT" ]; then
  PUBLIC_PORT="$(ask 'Port untuk web (tekan Enter untuk 80): ')"
  PUBLIC_PORT="${PUBLIC_PORT:-80}"
fi
[[ "$PUBLIC_PORT" =~ ^[0-9]+$ ]] && [ "$PUBLIC_PORT" -ge 1 ] && [ "$PUBLIC_PORT" -le 65535 ] || die "Port '$PUBLIC_PORT' tidak valid."
[ "$PUBLIC_PORT" != "$INTERNAL_PORT" ] || die "Port $INTERNAL_PORT dipakai internal oleh aplikasi; pilih port lain."
[ "$PUBLIC_PORT" != "443" ] || die "Untuk HTTPS pakai port 80 dengan domain; port 443 ikut dipakai otomatis."
if [ "$PUBLIC_PORT" = "80" ]; then USE_CADDY=1; else USE_CADDY=0; fi

PASSWORD="${PALET_PASSWORD:-$OLD_PASSWORD}"
if [ -z "$PASSWORD" ]; then
  PASSWORD="$(ask 'Buat password untuk membuka web (huruf/angka, min. 6 karakter): ')"
fi
[[ "$PASSWORD" =~ ^[A-Za-z0-9._-]{6,}$ ]] || die "Password harus minimal 6 karakter dan hanya berisi huruf, angka, titik, garis bawah, atau strip."

if [ "$USE_CADDY" = 0 ]; then
  # HTTPS certificates need ports 80/443, so a custom port always means plain HTTP by IP.
  if [ -n "${DOMAIN:-}" ]; then echo "Catatan: domain diabaikan karena port $PUBLIC_PORT memakai HTTP biasa."; fi
  DOMAIN=""
elif [ -z "${DOMAIN+x}" ]; then
  if [ -f "$ENV_FILE" ] && [ "$OLD_PORT" = "80" ]; then DOMAIN="$OLD_DOMAIN"
  else DOMAIN="$(ask 'Domain (kosongkan kalau belum punya, akses lewat IP): ')"; fi
fi
DOMAIN="$(printf '%s' "$DOMAIN" | tr -d '[:space:]' | sed 's#^https\?://##; s#/.*$##')"
if [ -n "$DOMAIN" ] && ! [[ "$DOMAIN" =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then die "Domain '$DOMAIN' tidak valid."; fi

if [ "$USE_CADDY" = 1 ]; then APP_PORT=$INTERNAL_PORT; APP_HOST=127.0.0.1; OPEN_PORTS="80 443"
else APP_PORT=$PUBLIC_PORT; APP_HOST=0.0.0.0; OPEN_PORTS="$PUBLIC_PORT"; fi

# ---- is the port free? ------------------------------------------------------
# Stop our own services first so the check only sees other programs.
systemctl stop palet-pelaminan caddy-palet >/dev/null 2>&1 || true
if [ "$USE_CADDY" = 1 ]; then CHECK="80|443|$INTERNAL_PORT"; else CHECK="$PUBLIC_PORT"; fi
busy="$( (ss -ltnp 2>/dev/null || true) | awk -v re=":($CHECK)\$" '$4 ~ re' )"
if [ -n "$busy" ]; then
  echo "$busy"
  die "Port $(echo "$CHECK" | tr '|' '/') sudah dipakai program lain (lihat di atas). Pilih port lain, misalnya: ... | sudo PORT=2002 bash"
fi

# ---- packages ---------------------------------------------------------------
say "Memasang alat dasar (curl, git, tar, xz)"
if command -v apt-get >/dev/null; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y >/dev/null
  apt-get install -y curl git tar xz-utils ca-certificates iproute2 >/dev/null
elif command -v dnf >/dev/null; then
  dnf install -y curl git tar xz ca-certificates iproute >/dev/null
elif command -v yum >/dev/null; then
  yum install -y curl git tar xz ca-certificates iproute >/dev/null
else
  die "Package manager tidak dikenali (butuh apt, dnf, atau yum)."
fi

if [ ! -x "$NODE_BIN" ] || [ "$("$NODE_BIN" -v)" != "$NODE_VERSION" ]; then
  say "Mengunduh Node.js $NODE_VERSION"
  tmp="$(mktemp -d)"
  curl -fsSL "https://nodejs.org/dist/$NODE_VERSION/node-$NODE_VERSION-linux-$NODE_ARCH.tar.xz" -o "$tmp/node.tar.xz"
  rm -rf /opt/node && mkdir -p /opt/node
  tar -xJf "$tmp/node.tar.xz" -C /opt/node --strip-components=1
  rm -rf "$tmp"
fi

if [ "$USE_CADDY" = 1 ] && [ ! -x "$CADDY_BIN" ]; then
  say "Mengunduh Caddy (web server + HTTPS otomatis)"
  curl -fsSL "https://caddyserver.com/api/download?os=linux&arch=$CADDY_ARCH" -o "$CADDY_BIN.tmp"
  chmod +x "$CADDY_BIN.tmp" && mv "$CADDY_BIN.tmp" "$CADDY_BIN"
fi

# ---- app code ---------------------------------------------------------------
id palet >/dev/null 2>&1 || useradd --system --home-dir "$DATA_DIR" --shell /usr/sbin/nologin palet
say "Mengambil kode dari $REPO_URL ($BRANCH)"
if [ -d "$APP_DIR/.git" ]; then
  git -C "$APP_DIR" fetch --depth 1 origin "$BRANCH"
  git -C "$APP_DIR" reset --hard FETCH_HEAD
else
  rm -rf "$APP_DIR"
  git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$APP_DIR"
fi
mkdir -p "$DATA_DIR" && chown palet:palet "$DATA_DIR" && chmod 700 "$DATA_DIR"

umask 077
{
  echo "# Palet Pelaminan settings (written by deploy/install.sh)"
  echo "# DOMAIN=$DOMAIN"
  echo "# PUBLIC_PORT=$PUBLIC_PORT"
  echo "PALET_PASSWORD=$PASSWORD"
  echo "PORT=$APP_PORT"
  echo "HOST=$APP_HOST"
  echo "DATA_DIR=$DATA_DIR"
} > "$ENV_FILE"
umask 022

cat > /etc/systemd/system/palet-pelaminan.service <<UNIT
[Unit]
Description=Palet Pelaminan
After=network.target

[Service]
User=palet
EnvironmentFile=$ENV_FILE
ExecStart=$NODE_BIN $APP_DIR/server/server.js
Restart=always
RestartSec=2
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
ReadWritePaths=$DATA_DIR

[Install]
WantedBy=multi-user.target
UNIT

# ---- web server (only for port 80) ------------------------------------------
if [ "$USE_CADDY" = 1 ]; then
  mkdir -p "$CADDY_DIR" /var/lib/caddy-palet
  printf '%s {\n\tencode gzip\n\treverse_proxy 127.0.0.1:%s\n}\n' "${DOMAIN:-:80}" "$INTERNAL_PORT" > "$CADDY_DIR/Caddyfile"
  cat > /etc/systemd/system/caddy-palet.service <<UNIT
[Unit]
Description=Caddy web server for Palet Pelaminan
After=network-online.target
Wants=network-online.target

[Service]
Environment=XDG_DATA_HOME=/var/lib/caddy-palet XDG_CONFIG_HOME=/var/lib/caddy-palet
ExecStart=$CADDY_BIN run --config $CADDY_DIR/Caddyfile --adapter caddyfile
Restart=always
RestartSec=3
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
UNIT
else
  systemctl disable caddy-palet >/dev/null 2>&1 || true
fi

# Open the OS-level firewall if one is running (the cloud console firewall is separate).
for p in $OPEN_PORTS; do
  if command -v ufw >/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then ufw allow "$p/tcp" >/dev/null; fi
  if command -v firewall-cmd >/dev/null && firewall-cmd --state >/dev/null 2>&1; then firewall-cmd --permanent --add-port="$p/tcp" >/dev/null; fi
done
if command -v firewall-cmd >/dev/null && firewall-cmd --state >/dev/null 2>&1; then firewall-cmd --reload >/dev/null; fi

# ---- start ------------------------------------------------------------------
say "Menjalankan layanan"
systemctl daemon-reload
systemctl enable palet-pelaminan >/dev/null 2>&1
systemctl restart palet-pelaminan
if [ "$USE_CADDY" = 1 ]; then systemctl enable caddy-palet >/dev/null 2>&1; systemctl restart caddy-palet; fi

sleep 2
code="$(curl -s -o /dev/null -w '%{http_code}' -u "palet:$PASSWORD" "http://127.0.0.1:$APP_PORT/api/palette" || true)"
[ "$code" = "200" ] || { journalctl -u palet-pelaminan -n 30 --no-pager; die "Aplikasi tidak merespons (kode $code)."; }
if [ "$USE_CADDY" = 1 ]; then
  systemctl is-active --quiet caddy-palet || { journalctl -u caddy-palet -n 30 --no-pager; die "Caddy gagal berjalan."; }
fi

IP="$(curl -fsS -4 --max-time 5 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')"
if [ -n "$DOMAIN" ]; then URL="https://$DOMAIN"
elif [ "$PUBLIC_PORT" = "80" ]; then URL="http://$IP"
else URL="http://$IP:$PUBLIC_PORT"; fi

printf '\n\033[1;32mSelesai!\033[0m\n'
echo "Buka:      $URL"
echo "Login:     nama pengguna bebas (mis. palet), password: yang tadi kamu buat"
echo "Update:    jalankan perintah instalasi yang sama sekali lagi"
echo "Firewall:  pastikan port TCP $(echo $OPEN_PORTS | sed 's/ / dan /') terbuka di firewall console cloud kamu."
if [ -n "$DOMAIN" ]; then
  echo "Catatan:   sertifikat HTTPS dibuat otomatis; pastikan DNS $DOMAIN mengarah ke $IP."
else
  echo "Catatan:   koneksi memakai HTTP biasa (tidak terenkripsi)."
fi
