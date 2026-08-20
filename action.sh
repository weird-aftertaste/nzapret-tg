#!/system/bin/sh
# action.sh for Magisk/KernelSU — Telegram-only quick toggle

MODDIR=${0%/*}
CLI="$MODDIR/system/bin/nzapret"

print_header() {
    echo "=== nzapret-tg Action ==="
    echo ""
}

require_cli() {
    [ -f "$CLI" ] || {
        echo "[-] Error: CLI utility not found at $CLI"
        exit 1
    }
}

is_running() {
    "$CLI" status | grep -q 'nztg: \[ON\]'
}

print_status_summary() {
    echo ""
    echo "[*] Current Status:"
    "$CLI" status | grep -E 'Module version:|nztg:|Mode:|nfqws2:|iptables/NFQUEUE:|Host:|Port:|Cloudflare proxy:'
}

print_header
require_cli

if is_running; then
    echo "[*] Telegram proxy is currently RUNNING."
    "$CLI" stop
else
    echo "[*] Telegram proxy is currently STOPPED."
    "$CLI" start
fi

print_status_summary

echo ""
echo "=== Done ==="
