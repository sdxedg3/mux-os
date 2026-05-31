#!/bin/bash
# mux-kill — Force-stop Android apps via Shizuku (rish) or ADB
# Part of Mux-OS
# Primary: Shizuku (rish) — no setup needed if Shizuku is running
# Fallback: ADB wireless debugging

MUX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADB_KEY="$MUX_ROOT/.adb_connected"
ADB_CONFIG="$MUX_ROOT/.adb_config"

C_RESET="\033[0m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_RED="\033[1;31m"
C_CYAN="\033[1;36m"

RISH_BIN="/data/data/com.termux/files/usr/bin/rish"

# ── Help / Usage ──────────────────────────────────────────────────

usage() {
    cat <<EOF
${C_CYAN}mux-kill — Force-stop Android apps${C_RESET}
  ${C_YELLOW}Shizuku (rish)${C_RESET} preferred · ${C_GRAY}ADB fallback${C_RESET}

  ${C_GREEN}mux kill <app>${C_RESET}      Force-stop an app
  ${C_GREEN}mux kill --list${C_RESET}      Show running apps (from dumpsys)
  ${C_GREEN}mux kill --setup${C_RESET}     Guide through one-time wireless ADB setup

${C_YELLOW}Prerequisites:${C_RESET}
  ${C_GREEN}Shizuku${C_RESET} (auto) — just have Shizuku running on your phone
  ${C_GRAY}ADB${C_RESET} (fallback) — enable Developer options + Wireless debugging

EOF
}

# ── Shizuku (rish) helpers ─────────────────────────────────────────

rish_available() {
    [ -x "$RISH_BIN" ] || return 1
    timeout 8 "$RISH_BIN" -c "echo ok" 2>/dev/null | grep -q "ok"
}

rish_force_stop() {
    local pkg="$1"
    local result
    # am force-stop first, then kill any lingering processes
    result=$("$RISH_BIN" -c "
      am force-stop $pkg 2>/dev/null
      sleep 1
      for p in \$(pidof $pkg ${pkg}_zygote 2>/dev/null); do
        kill -9 \$p 2>/dev/null
      done
      echo 'done'
    " 2>&1)
    local rc=$?
    if [ $rc -eq 0 ] || echo "$result" | grep -q "done"; then
        echo -e "${C_GREEN}✓ ${pkg} stopped (Shizuku)${C_RESET}"
        return 0
    else
        echo -e "${C_RED}✗ Shizuku force-stop failed:${C_RESET} ${result:-"unknown error"}"
        return 1
    fi
}

# ── ADB connection management ─────────────────────────────────────

adb_connect() {
    local port="${1:-}"
    
    if [ -z "$port" ]; then
        # Try saved config first
        if [ -f "$ADB_CONFIG" ]; then
            port=$(cat "$ADB_CONFIG")
        else
            return 1
        fi
    fi

    # Connect to the device's wireless debugging port
    local output
    output=$(adb connect "127.0.0.1:$port" 2>&1)
    
    if echo "$output" | grep -q "connected"; then
        echo -e "${C_GREEN}✓ ADB connected${C_RESET}"
        echo "$port" > "$ADB_CONFIG"
        touch "$ADB_KEY"
        return 0
    else
        echo -e "${C_RED}✗ Connection failed:${C_RESET} $output"
        rm -f "$ADB_KEY"
        return 1
    fi
}

adb_reconnect() {
    # Try to reconnect using saved config
    if [ -f "$ADB_CONFIG" ]; then
        echo -e "${C_YELLOW}→ Reconnecting ADB...${C_RESET}"
        adb kill-server 2>/dev/null
        adb start-server 2>/dev/null
        adb_connect
        return $?
    fi
    return 1
}

# ── Force-stop ────────────────────────────────────────────────────

force_stop() {
    local pkg="$1"
    
    if [ -z "$pkg" ]; then
        echo -e "${C_RED}✗ Usage: mux kill <app>${C_RESET}"
        return 1
    fi

    # Resolve app name to package
    local resolved_pkg=""
    if echo "$pkg" | grep -q '\.'; then
        resolved_pkg="$pkg"
    else
        resolved_pkg=$(grep -i "^$pkg," "$MUX_ROOT/app.csv" 2>/dev/null | head -1 | cut -d',' -f3 | tr -d ' "')
        if [ -z "$resolved_pkg" ]; then
            echo -e "${C_RED}✗ Cannot resolve '${pkg}' to a package name${C_RESET}"
            return 1
        fi
    fi

    # Try Shizuku (rish) first
    if rish_available; then
        rish_force_stop "$resolved_pkg"
        return $?
    fi

    # Fallback: ADB
    echo -e "${C_YELLOW}→ Shizuku not available, trying ADB...${C_RESET}"
    if [ ! -f "$ADB_KEY" ]; then
        echo -e "${C_YELLOW}→ ADB not connected. Attempting reconnect...${C_RESET}"
        adb_reconnect || {
            echo -e "${C_RED}✗ Neither Shizuku nor ADB available.${C_RESET}"
            echo "  Start Shizuku on your phone, or run 'mux kill --setup' for ADB."
            return 1
        }
    fi

    if ! adb get-state 2>/dev/null | grep -q "device"; then
        rm -f "$ADB_KEY"
        echo -e "${C_RED}✗ ADB connection lost.${C_RESET}"
        echo "  Run 'mux kill --setup' to reconnect, or start Shizuku."
        return 1
    fi

    echo -e "${C_YELLOW}→ Force-stopping: ${resolved_pkg}${C_RESET}"
    local result
    result=$(adb shell am force-stop "$resolved_pkg" 2>&1)
    local rc=$?
    
    if [ $rc -eq 0 ] && [ -z "$result" ]; then
        echo -e "${C_GREEN}✓ ${resolved_pkg} stopped (ADB)${C_RESET}"
        return 0
    else
        echo -e "${C_RED}✗ Failed:${C_RESET} ${result:-"unknown error"}"
        return 1
    fi
}

# ── List running apps ─────────────────────────────────────────────

list_running() {
    if [ ! -f "$ADB_KEY" ]; then
        adb_reconnect || {
            echo -e "${C_RED}✗ ADB not available${C_RESET}"
            return 1
        }
    fi
    
    echo -e "${C_CYAN}Recent / Running apps:${C_RESET}"
    adb shell dumpsys activity recents 2>/dev/null | grep 'Recent #' -A3 | grep 'intent=' | head -20 | while read line; do
        # Extract package name from intent
        echo "  $line" | grep -oP 'package=\K\S+' | sed 's/}$//'
    done | sort -u | while read pkg; do
        echo "  ${C_GREEN}$pkg${C_RESET}"
    done
}

# ── Setup guide ───────────────────────────────────────────────────

setup_guide() {
    cat <<EOF
${C_CYAN}══════════════════════════════════════════════${C_RESET}
${C_CYAN}  Mux-OS ADB Wireless Setup${C_RESET}
${C_CYAN}══════════════════════════════════════════════${C_RESET}

${C_YELLOW}Step 1: Enable Developer Options${C_RESET}
  Settings → About phone → Build number (tap 7 times)

${C_YELLOW}Step 2: Enable USB Debugging${C_RESET}
  Settings → Developer options → USB debugging → ON

${C_YELLOW}Step 3: Enable Wireless Debugging${C_RESET}
  Settings → Developer options → 无线调试 (Wireless debugging) → ON
  → Tap "无线调试" → 允许 (Allow)

${C_YELLOW}Step 4: Note the pairing info${C_RESET}
  You'll see "IP地址和端口: 192.168.x.x:xxxxx"
  ${C_RED}IMPORTANT:${C_RESET} Your phone and Termux must be on the SAME WiFi.

${C_YELLOW}Step 5: Pair via ADB${C_RESET}
  In Termux, run:
    adb pair 192.168.x.x:xxxxx  (port shown under "配对码配对")
    → Enter the 6-digit pairing code shown on your phone

${C_YELLOW}Step 6: Connect${C_RESET}
  adb connect 192.168.x.x:xxxxx  (port shown under "无线调试")
  → Authorize on your phone (check "Always allow")

${C_YELLOW}Step 7: Verify${C_RESET}
  Run: adb devices
  Should show: 192.168.x.x:xxxxx  device

${C_YELLOW}Step 8: Save connection${C_RESET}
  mux kill --save-port xxxxx

${C_GREEN}After setup, just use: mux kill chrome${C_RESET}
You only need to do steps 1-8 once (unless WiFi IP changes).

EOF
}

# ── Save port ─────────────────────────────────────────────────────

save_port() {
    local port="$1"
    if [ -z "$port" ]; then
        echo -e "${C_RED}✗ Usage: mux kill --save-port <PORT>${C_RESET}"
        return 1
    fi
    echo "$port" > "$ADB_CONFIG"
    echo -e "${C_GREEN}✓ Port $port saved${C_RESET}"
}

# ── Main ──────────────────────────────────────────────────────────

main() {
    case "${1:-}" in
        help|--help|-h)
            usage
            ;;
        --setup)
            setup_guide
            ;;
        --save-port)
            save_port "$2"
            ;;
        --list)
            list_running
            ;;
        connect|--connect)
            adb_connect "$2"
            ;;
        *)
            force_stop "$1"
            ;;
    esac
}

main "$@"
