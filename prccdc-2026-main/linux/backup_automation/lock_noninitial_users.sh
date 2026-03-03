#!/usr/bin/env bash
set -euo pipefail

#
# Lock all non-whitelisted users.
#
# Usage:
#   lock_noninitial_users.sh /path/to/init_passwd admin_user
#

[[ $# -eq 2 ]] || {
    echo "Usage: $0 /path/to/init_passwd admin_user" >&2
    exit 1
}

INIT_PASSWD="$1"
ADMIN_USER="$2"


log() {
    printf '[lock-users] %s\n' "$*"
}

die() {
    log "ERROR: $*"
    exit 1
}

# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------

[[ $EUID -eq 0 ]] || die "must be run as root"
[[ -n "${INIT_PASSWD:-}" ]] || die "initial passwd file argument missing"
[[ -n "${ADMIN_USER:-}" ]] || die "admin user argument missing"
[[ -f "$INIT_PASSWD" ]] || die "initial passwd file '$INIT_PASSWD' not found"

if ! getent passwd "$ADMIN_USER" >/dev/null; then
    die "admin user '$ADMIN_USER' does not exist"
fi

log "Initial passwd file: $INIT_PASSWD"
log "Preserved admin user: $ADMIN_USER"

# ---------------------------------------------------------------------------
# Build whitelist
# ---------------------------------------------------------------------------

declare -A allowed_users

while IFS=: read -r user _ uid _; do
    allowed_users["$user"]=1
done < "$INIT_PASSWD"

# ---------------------------------------------------------------------------
# Enforce policy
# ---------------------------------------------------------------------------

while IFS=: read -r user _ uid _; do
    # Skip system accounts (standard Linux convention)
    [[ "$uid" -lt 1000 ]] && continue

    case "$user" in
        root|"$ADMIN_USER")
            continue
            ;;
    esac

    if [[ -z "${allowed_users[$user]:-}" ]]; then
        log "Locking user: $user"
        usermod -L -e 1 "$user" || true

        # Enable after creating deny-ssh group:
            # create group: groupadd deny-ssh
            # add to end of /etc/ssh/sshd_config: DenyGroups deny-ssh
            # add user to deny group: usermod -a -G deny-ssh user
        log "Deny SSH connections: $user"
        usermod -a -G deny-ssh "$user" || true

        log "Remove user Shell: $user"
        usermod --shell /usr/sbin/nologin "$user" || true

        #Reload sshd
        systemctl reload sshd || true
    fi
done < /etc/passwd

log "User lock enforcement complete"
