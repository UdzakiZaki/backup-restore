#!/bin/bash
set -euo pipefail

[ -f /etc/default/backup-site ] && . /etc/default/backup-site

BACKUP_HOST="${BACKUP_HOST:-192.0.2.20}"
BACKUP_USER="${BACKUP_USER:-backup}"
BACKUP_DIR="${BACKUP_DIR:-/srv/backups/main}"
SSH_KEY="${SSH_KEY:-/root/.ssh/id_backup}"
RESTORE_DIR="${RESTORE_DIR:-/var/backups/site/restore}"
TARGET_ROOT="${TARGET_ROOT:-/}"

PATHS=(
  srv/site
  etc/nginx
)

REMOTE="$BACKUP_USER@$BACKUP_HOST"
SSH_OPTS=(-i "$SSH_KEY" -o BatchMode=yes -o StrictHostKeyChecking=yes)
NAME="${1:-}"

log() { echo "restore-site: $*"; }
trap 'rc=$?; echo "restore-site: FAILED at line $LINENO (exit $rc)" >&2' ERR

if [ "$(id -u)" -ne 0 ]; then
  echo "restore-site: must be run as root" >&2
  exit 2
fi

START="$(date +%s.%N)"

if [ -z "$NAME" ]; then
  NAME="$(ssh "${SSH_OPTS[@]}" "$REMOTE" "cd '$BACKUP_DIR' && ls -1t main-*.tar.gz | head -n 1")"
fi
if [ -z "$NAME" ]; then
  echo "restore-site: no backups found on the server" >&2
  exit 1
fi

log "using $NAME"
install -d -m 700 "$RESTORE_DIR"
rsync -e "ssh ${SSH_OPTS[*]}" --partial "$REMOTE:$BACKUP_DIR/$NAME" "$REMOTE:$BACKUP_DIR/$NAME.sha256" "$RESTORE_DIR/"

log "verifying checksum"
if ! ( cd "$RESTORE_DIR" && sha256sum --check "$NAME.sha256" ); then
  echo "restore-site: checksum FAILED, nothing was restored" >&2
  exit 1
fi

log "extracting: ${PATHS[*]}"
tar --extract --gzip --preserve-permissions --same-owner --numeric-owner --xattrs --acls --selinux \
    --file "$RESTORE_DIR/$NAME" -C "$TARGET_ROOT" "${PATHS[@]}"

log "restoring SELinux contexts"
restorecon -R /srv/site /etc/nginx

log "checking nginx configuration and reloading"
nginx -t
systemctl reload-or-restart nginx

curl -fsS -o /dev/null -w "restore-site: site answers HTTP %{http_code}\n" --max-time 5 http://127.0.0.1/

END="$(date +%s.%N)"
log "finished in $(awk -v s="$START" -v e="$END" 'BEGIN { printf "%.1f", e - s }') s"
