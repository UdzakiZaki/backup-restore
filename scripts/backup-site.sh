#!/bin/bash
set -euo pipefail

[ -f /etc/default/backup-site ] && . /etc/default/backup-site

BACKUP_HOST="${BACKUP_HOST:-192.0.2.20}"
BACKUP_USER="${BACKUP_USER:-backup}"
BACKUP_DIR="${BACKUP_DIR:-/srv/backups/main}"
SSH_KEY="${SSH_KEY:-/root/.ssh/id_backup}"
WORK_DIR="${WORK_DIR:-/var/backups/site}"
SOURCE_ROOT="${SOURCE_ROOT:-/}"
KEEP_REMOTE="${KEEP_REMOTE:-7}"
KEEP_LOCAL="${KEEP_LOCAL:-2}"

SOURCES=(
  srv/site
  etc/nginx
  etc/ssh/sshd_config.d
  etc/firewalld/zones
  etc/audit/rules.d
  etc/sudoers.d
)

REMOTE="$BACKUP_USER@$BACKUP_HOST"
SSH_OPTS=(-i "$SSH_KEY" -o BatchMode=yes -o StrictHostKeyChecking=yes)
STAMP="$(date +%Y%m%d-%H%M%S)"
NAME="main-$STAMP.tar.gz"
START="$(date +%s)"

log() { echo "backup-site: $*"; }
trap 'rc=$?; echo "backup-site: FAILED at line $LINENO (exit $rc)" >&2' ERR

install -d -m 700 "$WORK_DIR"

log "creating archive $NAME"
tar --create --gzip --preserve-permissions --numeric-owner --xattrs --acls --selinux \
    --file "$WORK_DIR/$NAME" -C "$SOURCE_ROOT" "${SOURCES[@]}"

log "calculating checksum"
( cd "$WORK_DIR" && sha256sum "$NAME" > "$NAME.sha256" && sha256sum --check --status "$NAME.sha256" )
log "archive size: $(du -h "$WORK_DIR/$NAME" | cut -f1)"

log "copying to $REMOTE:$BACKUP_DIR"
rsync -e "ssh ${SSH_OPTS[*]}" --partial "$WORK_DIR/$NAME" "$WORK_DIR/$NAME.sha256" "$REMOTE:$BACKUP_DIR/"

log "verifying checksum on the backup server"
ssh "${SSH_OPTS[@]}" "$REMOTE" "cd '$BACKUP_DIR' && sha256sum --check '$NAME.sha256'"

log "removing old copies (keep $KEEP_REMOTE on the server, $KEEP_LOCAL locally)"
ssh "${SSH_OPTS[@]}" "$REMOTE" "cd '$BACKUP_DIR' && ls -1t main-*.tar.gz | tail -n +$((KEEP_REMOTE + 1)) | while read -r f; do rm -f -- \"\$f\" \"\$f.sha256\"; done"
( cd "$WORK_DIR" && ls -1t main-*.tar.gz | tail -n +$((KEEP_LOCAL + 1)) | while read -r f; do rm -f -- "$f" "$f.sha256"; done )

log "done in $(( $(date +%s) - START )) s: $NAME"
