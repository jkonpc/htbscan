#!/bin/bash
# htbscan.sh - adaptive nmap scanner for htb/pentesting
# starts with a quick scan and escalates through increasingly
# aggressive techniques until it finds open ports
#
# jkonpc 2026

VERSION="1.0.0"

usage() {
    echo "htbscan v${VERSION}"
    echo ""
    echo "usage: $0 <ip> [outdir]"
    echo ""
    echo "  ip       target ip address"
    echo "  outdir   output directory for nmap files (default: nmap)"
    echo ""
    echo "scan stages:"
    echo "  1. syn scan - top 1000 ports"
    echo "  2. syn scan - top 10000 ports"
    echo "  3. syn scan - all 65535 ports (aggressive rate)"
    echo "  4. syn scan - all 65535 ports (slow, evades rate limiting)"
    echo "  5. udp scan - top 100 ports"
    echo ""
    echo "each tcp stage only runs if the previous one found nothing."
    echo "version/script detection runs automatically on any open ports."
    echo "udp always runs regardless of tcp results."
    exit 0
}

[[ "$1" == "-h" || "$1" == "--help" ]] && usage
TARGET="${1:?usage: $0 <ip> [outdir] (try -h for help)}"
OUTDIR="${2:-nmap}"
mkdir -p "$OUTDIR"

G='\033[0;32m' Y='\033[1;33m' R='\033[0;31m' C='\033[0;36m' N='\033[0m'

extract_ports() {
    grep -oP '^\d+/\w+\s+open' "$1" 2>/dev/null | cut -d/ -f1 | sort -un | tr '\n' ',' | sed 's/,$//'
}

# ping check - auto set -Pn if icmp is blocked
PN=""
if ! ping -c 1 -W 2 "$TARGET" &>/dev/null; then
    echo -e "${Y}[!]${N} icmp blocked, using -Pn"
    PN="-Pn"
fi

# stage 1 - top 1000
echo -e "${C}[*]${N} stage 1: syn top 1000"
sudo nmap -sS $PN --min-rate 3000 -T4 "$TARGET" -oA "$OUTDIR/tcp_top1000" 2>/dev/null
PORTS=$(extract_ports "$OUTDIR/tcp_top1000.nmap")

# stage 2 - top 10000
if [[ -z "$PORTS" ]]; then
    echo -e "${Y}[!]${N} nothing in top 1000"
    echo -e "${C}[*]${N} stage 2: syn top 10000"
    sudo nmap -sS $PN --top-ports 10000 --min-rate 4000 -T4 "$TARGET" -oA "$OUTDIR/tcp_top10000" 2>/dev/null
    PORTS=$(extract_ports "$OUTDIR/tcp_top10000.nmap")
fi

# stage 3 - all ports, aggressive
if [[ -z "$PORTS" ]]; then
    echo -e "${Y}[!]${N} nothing in top 10000"
    echo -e "${C}[*]${N} stage 3: syn all ports (aggressive)"
    sudo nmap -sS $PN -p- --min-rate 5000 -T4 "$TARGET" -oA "$OUTDIR/tcp_full" 2>/dev/null
    PORTS=$(extract_ports "$OUTDIR/tcp_full.nmap")
fi

# stage 4 - all ports, slow (for rate limited / weird fw targets)
if [[ -z "$PORTS" ]]; then
    echo -e "${Y}[!]${N} still nothing, slowing down"
    echo -e "${C}[*]${N} stage 4: syn all ports (slow)"
    sudo nmap -sS $PN -p- -T2 "$TARGET" -oA "$OUTDIR/tcp_slow" 2>/dev/null
    PORTS=$(extract_ports "$OUTDIR/tcp_slow.nmap")
fi

# version + script scan on whatever we found
if [[ -n "$PORTS" ]]; then
    echo -e "${G}[+]${N} open tcp: $PORTS"
    echo -e "${C}[*]${N} running version/script scan"
    sudo nmap -sCV $PN -p "$PORTS" "$TARGET" -oA "$OUTDIR/tcp_detailed" 2>/dev/null
    echo ""
    cat "$OUTDIR/tcp_detailed.nmap"
    echo ""
else
    echo -e "${R}[-]${N} no open tcp ports found"
fi

# stage 5 - udp always runs
echo -e "${C}[*]${N} stage 5: udp top 100"
sudo nmap -sU $PN --top-ports 100 --min-rate 1000 "$TARGET" -oA "$OUTDIR/udp_top100" 2>/dev/null
UDP=$(extract_ports "$OUTDIR/udp_top100.nmap")

if [[ -n "$UDP" ]]; then
    echo -e "${G}[+]${N} open udp: $UDP"
    sudo nmap -sUCV $PN -p "$UDP" "$TARGET" -oA "$OUTDIR/udp_detailed" 2>/dev/null
    echo ""
    cat "$OUTDIR/udp_detailed.nmap"
else
    echo -e "${Y}[!]${N} no open udp in top 100"
fi

# summary
echo ""
echo "--- scan complete ---"
echo "target:  $TARGET"
echo "tcp:     ${PORTS:-nothing}"
echo "udp:     ${UDP:-nothing}"
echo "output:  $OUTDIR/"
