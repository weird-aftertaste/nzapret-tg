#!/system/bin/sh
# nzapret-tg — Telegram-only service
# Starts only the local nztg MTProto proxy. No nfqws2/NFQUEUE rules are created.

MODDIR=${0%/*}
EVENTLOG="$MODDIR/nzapret-events.log"
NZTG_BIN="$MODDIR/bin/nztg"
TGPROXY_CONF="$MODDIR/tgproxy.conf"
TG_SECRET_FILE="$MODDIR/.tg_secret"
TG_LINK_FILE="$MODDIR/.tg_link"
TG_LOGFILE="$MODDIR/nztg.log"
TG_PROCESS_NAME="nztg"
PRIVATE_DNS_INIT_FILE="$MODDIR/.private_dns_initialized"
DEFAULT_PRIVATE_DNS_HOSTNAME="xbox-dns.ru"
START_MODE="${1:-boot}"
CHAIN="nzapret_out"

. "$MODDIR/common.sh"

fail() {
    log_event ERROR "$*"
    exit 1
}

wait_for_boot_completion() {
    if [ "$START_MODE" = "manual" ] && [ "$(getprop sys.boot_completed)" = "1" ]; then
        return 0
    fi
    until [ "$(getprop sys.boot_completed)" = "1" ]; do
        sleep 1
    done
    [ "$START_MODE" = "manual" ] || sleep 5
}

# Remove leftovers when upgrading from the full nzapret build. We never add
# firewall rules in TG-only mode; this function only removes the old chain.
cleanup_legacy_nfqws() {
    killall nfqws2 2>/dev/null
    for _tbl in iptables ip6tables; do
        command -v "$_tbl" >/dev/null 2>&1 || continue
        for _hook in OUTPUT FORWARD; do
            while "$_tbl" -w -t mangle -C "$_hook" -j "$CHAIN" >/dev/null 2>&1; do
                "$_tbl" -w -t mangle -D "$_hook" -j "$CHAIN" >/dev/null 2>&1 || break
            done
        done
        "$_tbl" -w -t mangle -F "$CHAIN" >/dev/null 2>&1
        "$_tbl" -w -t mangle -X "$CHAIN" >/dev/null 2>&1
    done
}

start_tgproxy() {
    [ -f "$NZTG_BIN" ] || fail "nztg binary missing: $NZTG_BIN"
    chmod +x "$NZTG_BIN" 2>/dev/null || fail "cannot chmod nztg"
    ensure_tgproxy_conf || fail "cannot create tgproxy.conf"

    killall "$TG_PROCESS_NAME" 2>/dev/null
    sleep 1

    [ -f "$TG_LOGFILE" ] && mv -f "$TG_LOGFILE" "$TG_LOGFILE.prev" 2>/dev/null
    : > "$TG_LOGFILE" 2>/dev/null

    # tg_build_args emits validated, space-free tokens; word-splitting is intended.
    # shellcheck disable=SC2046
    "$NZTG_BIN" $(tg_build_args) --secret-file "$TG_SECRET_FILE" --link-file "$TG_LINK_FILE" >> "$TG_LOGFILE" 2>&1 &
    _pid=$!
    sleep 1
    if kill -0 "$_pid" 2>/dev/null; then
        log_event TGPROXY "TG-only proxy started (pid: $_pid)"
        return 0
    fi

    log_event ERROR "nztg failed to start, see $TG_LOGFILE"
    return 1
}

wait_for_boot_completion
log_event START "TG-only service started (mode: $START_MODE)"

# Do not initialize/change Android Private DNS in TG-only mode.
cleanup_legacy_nfqws
start_tgproxy || exit 1
