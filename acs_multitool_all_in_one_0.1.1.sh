#!/usr/bin/env bash
# AC's MultiTool 0.1.1 — self-contained network toolkit
# © AC Kondo 1999–2026
# Bash built-ins and standard OS utilities only; optional Nmap/Burp integration.
set -u
C_RESET=$'\033[0m'; C_BLUE=$'\033[1;34m'
header(){ printf '\n%s=== AC\047s MultiTool 0.1.1 ===%s\n' "$C_BLUE" "$C_RESET"; }
pause(){ read -r -p 'Press Enter to continue...' _; }
has(){ command -v "$1" >/dev/null 2>&1; }
valid_host(){ [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]] && [[ "$1" != -* ]]; }
ask_host(){ read -r -p 'Host/IP: ' HOST; valid_host "$HOST" || { echo 'Invalid host'; return 1; }; }
permission(){ read -r -p 'Confirm you own or are authorized to test this target [y/N]: ' reply; [[ "$reply" =~ ^[Yy]$ ]]; }
port_ok(){ [[ "$1" =~ ^[0-9]+$ ]] && ((10#$1 >= 1 && 10#$1 <= 65535)); }
# Bash /dev/tcp is supported by Bash, not POSIX sh.
tcp_probe(){ local host="$1" port="$2" timeout_s="${3:-2}"; if has timeout; then timeout "$timeout_s" bash -c 'echo > /dev/tcp/"$1"/"$2"' _ "$host" "$port" 2>/dev/null; elif has perl; then perl -MIO::Socket::INET -e 'exit(IO::Socket::INET->new(PeerAddr=>$ARGV[0],PeerPort=>$ARGV[1],Proto=>"tcp",Timeout=>2)?0:1)' "$host" "$port" 2>/dev/null; else (echo > "/dev/tcp/$host/$port") 2>/dev/null; fi; }
scan_ports(){ local start end p count=0; ask_host || return; permission || { echo 'Cancelled'; return; }; read -r -p 'Start port [1]: ' start; start=${start:-1}; read -r -p 'End port [1024]: ' end; end=${end:-1024}; port_ok "$start" && port_ok "$end" && ((10#$end >= 10#$start)) && ((10#$end - 10#$start <= 1023)) || { echo 'Use a range of at most 1024 valid ports.'; return; }; echo 'Scanning TCP ports (may take a while)...'; for ((p=10#$start;p<=10#$end;p++)); do if tcp_probe "$HOST" "$p" 1; then printf 'OPEN %s/tcp\n' "$p"; ((count+=1)); fi; done; printf '%d open port(s) found.\n' "$count"; }
quick_scan(){ local p; ask_host || return; permission || return; for p in 21 22 25 53 80 110 143 443 445 3306 3389 5432 5900 8080 8443; do if tcp_probe "$HOST" "$p" 2; then echo "OPEN $p/tcp"; fi; done; }
local_ports(){ if has ss; then ss -ltn; elif has lsof; then lsof -nP -iTCP -sTCP:LISTEN; elif has netstat; then netstat -an; else echo 'No socket-listing utility found'; fi; }
dns_lookup(){ ask_host || return; if has dig; then dig "$HOST"; elif has nslookup; then nslookup "$HOST"; elif has getent; then getent hosts "$HOST"; else echo 'No DNS utility available'; fi; }
ping_host(){ ask_host || return; if has ping; then ping -c 4 "$HOST"; else echo 'ping unavailable'; fi; }
http_headers(){ local url; read -r -p 'HTTP(S) URL: ' url; [[ "$url" =~ ^https?://[A-Za-z0-9._:-]+(/[A-Za-z0-9._~/%?=\&+,-]*)?$ ]] || { echo 'Invalid URL'; return; }; if has curl; then curl -I -L --max-time 10 -- "$url"; elif has python3; then python3 - "$url" <<'PY'
import sys,urllib.request
try:
 r=urllib.request.urlopen(urllib.request.Request(sys.argv[1],method='HEAD'),timeout=10)
 print('HTTP',r.status); print(r.headers)
except Exception as e: print('Request failed:',e)
PY
else echo 'curl or python3 required'; fi; }
trace_host(){ ask_host || return; if has traceroute; then traceroute "$HOST"; elif has tracepath; then tracepath "$HOST"; else echo 'Install traceroute or tracepath'; fi; }
network_info(){ if has ip; then ip -brief address; elif has ifconfig; then ifconfig; else echo 'Network address tool not found'; fi; }
nmap_scan(){ ask_host || return; permission || return; if has nmap; then nmap -sT -sV --top-ports 100 -- "$HOST"; else echo 'Nmap is not installed. Use the built-in TCP scanner instead (menu 1 or 2).'; fi; }
burp_launch(){ local jar=''; if has burpsuite; then burpsuite & return; fi; if has burp; then burp & return; fi; for candidate in "${BURP_JAR:-}" "$HOME/BurpSuiteCommunity.jar" "$HOME/Downloads/burpsuite_community.jar"; do if [[ -n "$candidate" && -f "$candidate" ]]; then jar=$candidate; break; fi; done; if [[ -n "$jar" ]] && has java; then java -jar "$jar" & else echo 'Burp Suite cannot be embedded as a Bash script; install Burp Suite Community and set BURP_JAR if needed.'; fi; }
web_proxy(){ local port; read -r -p 'Local proxy listening port [8080]: ' port; port=${port:-8080}; port_ok "$port" || { echo 'Invalid port'; return; }; echo "Configure your browser proxy to 127.0.0.1:$port after starting Burp Suite."; burp_launch; }
dependencies(){ for c in bash curl python3 nmap burpsuite burp java ss lsof dig nslookup ping traceroute timeout perl; do if has "$c"; then printf '[OK] %s\n' "$c"; else printf '[--] %s\n' "$c"; fi; done; }
while :; do
 header
 cat <<'MENU'
 1) Built-in TCP port scanner (up to 1024 ports)
 2) Built-in common-port scan
 3) Local listening ports
 4) DNS lookup
 5) Ping
 6) HTTP response headers
 7) Traceroute
 8) Network interface information
 9) Nmap service scan (optional external Nmap)
10) Launch Burp Suite (optional external Burp)
11) Burp proxy setup guidance / launch
12) Dependency check
 0) Exit
MENU
 read -r -p 'Choice: ' choice || exit 0
 case "$choice" in
 1) scan_ports;; 2) quick_scan;; 3) local_ports;; 4) dns_lookup;; 5) ping_host;; 6) http_headers;; 7) trace_host;; 8) network_info;; 9) nmap_scan;; 10) burp_launch;; 11) web_proxy;; 12) dependencies;; 0) exit 0;; *) echo 'Invalid option';;
 esac
 pause
 done
