#!/bin/bash
# Panel değişikliklerinden sonra tek komutla yeniden başlat.
# Panel systemd altında çalışır; elle nohup açmak 8080'i kapar ve
# coptc-dashboard.service sonsuz restart döngüsüne girer.
set -e
cd "$(dirname "$0")/.."
if [ -f .env ]; then set -a; . ./.env; set +a; fi
PORT="${COPTC_PORT:-8080}"

systemctl restart coptc-dashboard
sleep 3
systemctl is-active --quiet coptc-dashboard || {
  echo "Dashboard başlamadı — journalctl -u coptc-dashboard -n 30"
  exit 1
}
echo "Dashboard :$PORT — PID $(systemctl show coptc-dashboard -p MainPID --value)"
