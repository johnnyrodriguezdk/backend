#!/bin/bash
# ============================================================
# INSTALADOR - BACKEND MANAGER by JOHNNY (@Jrcelulares)
# Versión: 6.0 EXTENDED DEVOPS EDITION
# 20 opciones originales + API + Dashboard + JSON + Logs + Traffic
# ============================================================

VERDE='\e[1;32m'
ROJO='\e[1;31m'
AMARILLO='\e[1;33m'
CIAN='\e[1;36m'
SEMCOR='\e[0m'

if [[ $EUID -ne 0 ]]; then
    echo -e "${ROJO}[✗] Ejecuta como root: sudo bash $0${SEMCOR}"
    exit 1
fi

echo -e "${CIAN}════════════════════════════════════════════════════════${SEMCOR}"
echo -e "\E[41;1;37m   INSTALADOR - BACKEND MANAGER by JOHNNY (EXTENDED)   \E[0m"
echo -e "${CIAN}════════════════════════════════════════════════════════${SEMCOR}"

if [ -f /root/superc4mpeon.sh ]; then
    echo -e "${AMARILLO}[!] El script actual será reemplazado. Se hará un backup.${SEMCOR}"
    cp /root/superc4mpeon.sh /root/superc4mpeon.sh.backup.$(date +%Y%m%d%H%M%S)
    echo -e "${VERDE}[✓] Backup creado.${SEMCOR}"
fi

echo -e "${AMARILLO}[ℹ] Instalando dependencias necesarias...${SEMCOR}"
export DEBIAN_FRONTEND=noninteractive
apt update -y
apt install -y nginx curl wget speedtest-cli ufw bc net-tools jq vnstat python3 python3-pip python3-venv ca-certificates
pip3 install --break-system-packages flask requests psutil 2>/dev/null || pip3 install flask requests psutil

mkdir -p /etc/nginx/superc4mpeon_backups
touch /etc/nginx/superc4mpeon_users.txt
mkdir -p /root/superc4mpeon_backups

# ============================================================
# EXTENDED: Estructura /etc/backend-manager/
# ============================================================
BM_BASE="/etc/backend-manager"
BM_DATA="${BM_BASE}/data"
BM_WEB="/var/www/backend-manager"
BM_BACKUP="/root/backend-backups"

mkdir -p "${BM_BASE}" "${BM_DATA}" "${BM_WEB}" "${BM_BACKUP}"

for jsonfile in users.json backends.json domains.json traffic.json logs.json settings.json payments.json resellers.json stats.json; do
    [ ! -f "${BM_DATA}/${jsonfile}" ] && echo "[]" > "${BM_DATA}/${jsonfile}"
    [ ! -s "${BM_DATA}/${jsonfile}" ] && echo "[]" > "${BM_DATA}/${jsonfile}"
done

chmod 755 "${BM_BASE}"
chmod 700 "${BM_DATA}"
chmod 600 "${BM_DATA}"/*.json
# ============================================================
# EXTENDED: API Flask (/etc/backend-manager/api_server.py)
# ============================================================
cat > "${BM_BASE}/api_server.py" << 'PYEOF'
#!/usr/bin/env python3
import json, os, psutil
from flask import Flask, jsonify
from datetime import datetime

app = Flask(__name__)
DATA = "/etc/backend-manager/data"

def rj(f):
    try:
        with open(os.path.join(DATA, f)) as fh:
            return json.load(fh)
    except:
        return []

@app.get("/api/status")
def status():
    return jsonify({"status":"online","version":"6.0","time":datetime.utcnow().isoformat()+"Z"})

@app.get("/api/backends")
def backends():
    return jsonify(rj("backends.json"))

@app.get("/api/users")
def users():
    return jsonify(rj("users.json"))

@app.get("/api/traffic")
def traffic():
    return jsonify(rj("traffic.json"))

@app.get("/api/server")
def server():
    vm = psutil.virtual_memory()
    du = psutil.disk_usage("/")
    nc = psutil.net_io_counters()
    return jsonify({
        "cpu_percent": psutil.cpu_percent(interval=0.3),
        "load_avg": list(os.getloadavg()),
        "ram": {"percent": vm.percent, "total": vm.total, "used": vm.used},
        "disk": {"percent": du.percent, "total": du.total, "used": du.used},
        "net": {"bytes_sent": nc.bytes_sent, "bytes_recv": nc.bytes_recv},
        "uptime_seconds": int(datetime.now().timestamp() - psutil.boot_time())
    })

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000, debug=False)
PYEOF
chmod +x "${BM_BASE}/api_server.py"

cat > /etc/systemd/system/backend-manager-api.service << 'SVCEOF'
[Unit]
Description=Backend Manager API (Flask)
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /etc/backend-manager/api_server.py
Restart=always
RestartSec=2
User=root
WorkingDirectory=/etc/backend-manager

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable backend-manager-api >/dev/null 2>&1
systemctl restart backend-manager-api >/dev/null 2>&1
# ============================================================
# EXTENDED: Dashboard Web (/var/www/backend-manager/index.html)
# ============================================================
cat > "${BM_WEB}/index.html" << 'HTMLEOF'
<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>Backend Manager Dashboard</title>
<script src="https://cdn.tailwindcss.com"></script>
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body class="bg-gray-950 text-gray-100">
<div class="max-w-6xl mx-auto p-6">
<h1 class="text-2xl font-bold text-blue-400 mb-6">Backend Manager Dashboard</h1>
<div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
<div class="bg-gray-900 rounded p-4 border border-gray-800">
<div class="text-gray-400 text-sm">CPU</div>
<div id="cpu" class="text-3xl font-bold">--%</div>
</div>
<div class="bg-gray-900 rounded p-4 border border-gray-800">
<div class="text-gray-400 text-sm">RAM</div>
<div id="ram" class="text-3xl font-bold">--%</div>
</div>
<div class="bg-gray-900 rounded p-4 border border-gray-800">
<div class="text-gray-400 text-sm">DISCO</div>
<div id="disk" class="text-3xl font-bold">--%</div>
</div>
<div class="bg-gray-900 rounded p-4 border border-gray-800">
<div class="text-gray-400 text-sm">UPTIME</div>
<div id="uptime" class="text-3xl font-bold">--</div>
</div>
</div>
<div class="grid grid-cols-1 lg:grid-cols-2 gap-4 mb-6">
<div class="bg-gray-900 rounded p-4 border border-gray-800">
<h2 class="font-semibold mb-3">Backends</h2>
<table class="w-full text-sm">
<thead class="text-gray-400"><tr><th class="text-left py-1">Nombre</th><th class="text-left py-1">Target</th><th class="text-left py-1">Estado</th></tr></thead>
<tbody id="btable" class="divide-y divide-gray-800"></tbody>
</table>
</div>
<div class="bg-gray-900 rounded p-4 border border-gray-800">
<h2 class="font-semibold mb-3">Tráfico por Backend</h2>
<canvas id="tchart" height="160"></canvas>
</div>
</div>
</div>
<script>
function hb(b){if(!b&&b!==0)return"--";const u=["B","KB","MB","GB","TB"];let i=0,n=Number(b);while(n>=1024&&i<u.length-1){n/=1024;i++;}return n.toFixed(1)+" "+u[i];}
function hs(s){const h=Math.floor(s/3600),m=Math.floor((s%3600)/60);return h+"h "+m+"m";}
let tc;
async function load(){
try{
const sv=await(await fetch("/api/server")).json();
document.getElementById("cpu").textContent=sv.cpu_percent.toFixed(0)+"%";
document.getElementById("ram").textContent=sv.ram.percent.toFixed(0)+"%";
document.getElementById("disk").textContent=sv.disk.percent.toFixed(0)+"%";
document.getElementById("uptime").textContent=hs(sv.uptime_seconds);
const bk=await(await fetch("/api/backends")).json();
const tb=document.getElementById("btable");
tb.innerHTML="";
bk.forEach(b=>{const tr=document.createElement("tr");tr.innerHTML='<td class="py-1">'+
(b.name||"--")+'</td><td class="py-1 text-gray-300">'+(b.target||(b.ip+":"+b.port)||"--")+
'</td><td class="py-1">'+(b.status||"active")+"</td>";tb.appendChild(tr);});
const tf=await(await fetch("/api/traffic")).json();
const lb=tf.map(x=>x.name||"--"),vl=tf.map(x=>x.bytes||0);
if(!tc){const ctx=document.getElementById("tchart").getContext("2d");
tc=new Chart(ctx,{type:"bar",data:{labels:lb,datasets:[{label:"Bytes",data:vl,backgroundColor:"#3b82f6"}]},
options:{plugins:{legend:{display:false},tooltip:{callbacks:{label:c=>hb(c.raw)}}},
scales:{y:{ticks:{callback:v=>hb(v)},grid:{color:"#1f2937"}},x:{grid:{display:false}}}}});
}else{tc.data.labels=lb;tc.data.datasets[0].data=vl;tc.update();}
}catch(e){console.error(e);}
}
load();setInterval(load,5000);
</script>
</body>
</html>
HTMLEOF

# ============================================================
# EXTENDED: Nginx log format para tráfico por backend
# ============================================================
cat > /etc/nginx/conf.d/backend-manager-logformat.conf << 'NGXLOG'
log_format bm_traffic '$time_iso8601|$remote_addr|$http_backend|$bytes_sent|$request_length|$request';
access_log /var/log/nginx/backend-manager.log bm_traffic;
NGXLOG

# ============================================================
# EXTENDED: Nginx config para dashboard + API proxy
# ============================================================
cat > /etc/nginx/sites-available/backend-manager-dashboard << 'NGXDASH'
server {
    listen 8081;
    server_name _;

    location / {
        root /var/www/backend-manager;
        index index.html;
        try_files $uri $uri/ =404;
    }

    location /api {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
NGXDASH
ln -sf /etc/nginx/sites-available/backend-manager-dashboard /etc/nginx/sites-enabled/ 2>/dev/null

# ============================================================
# EXTENDED: Cron backup diario
# ============================================================
cat > /etc/cron.daily/backend-manager-backup << 'CRONEOF'
#!/bin/bash
DEST="/root/backend-backups"
TS="$(date +%Y%m%d_%H%M%S)"
mkdir -p "$DEST"
tar -czf "$DEST/backup_${TS}.tar.gz" \
    /etc/backend-manager/data \
    /etc/nginx/sites-available \
    /etc/nginx/sites-enabled \
    /etc/nginx/superc4mpeon_users.txt \
    2>/dev/null || true
find "$DEST" -name "backup_*.tar.gz" -mtime +30 -delete 2>/dev/null || true
CRONEOF
chmod +x /etc/cron.daily/backend-manager-backup
# ============================================================
# GENERAR EL SCRIPT PRINCIPAL /root/superc4mpeon.sh
# ============================================================
cat > /root/superc4mpeon.sh << 'EOF'
#!/bin/bash
# ==================================================
# BACKEND MANAGER by JOHNNY (@Jrcelulares)
# VERSIÓN 6.0 EXTENDED DEVOPS EDITION
# ==================================================

NEGRITO='\e[1m'
SEMCOR='\e[0m'
VERDE='\e[1;32m'
ROJO='\e[1;31m'
AMARILLO='\e[1;33m'
AZUL='\e[1;34m'
MORADO='\e[1;35m'
CIAN='\e[1;36m'
BLANCO='\e[1;37m'
TURQUESA='\e[1;96m'

BACKEND_CONF="/etc/nginx/sites-available/superc4mpeon"
BACKEND_ENABLED="/etc/nginx/sites-enabled/superc4mpeon"
USER_DATA="/etc/nginx/superc4mpeon_users.txt"
BACKUP_DIR="/root/superc4mpeon_backups"

BM_DATA="/etc/backend-manager/data"
BM_LOGS="${BM_DATA}/logs.json"
BM_BACKENDS="${BM_DATA}/backends.json"
BM_TRAFFIC="${BM_DATA}/traffic.json"
BM_DOMAINS="${BM_DATA}/domains.json"
BM_TRAFFIC_LOG="/var/log/nginx/backend-manager.log"

msg() {
    case $1 in
        -tit) echo -e "${MORADO}════════════════════════════════════════════════════════${SEMCOR}"
              echo -e "${BLANCO}${NEGRITO}
                  $2${SEMCOR}"
              echo -e "${MORADO}════════════════════════════════════════════════════════${SEMCOR}" ;;
        -bar) echo -e "${CIAN}════════════════════════════════════════════════════════${SEMCOR}" ;;
        -bar2) echo -e "${AMARILLO}────────────────────────────────────────────────────────${SEMCOR}" ;;
        -verd) echo -e "${VERDE}${NEGRITO}[✓] $2${SEMCOR}" ;;
        -verm) echo -e "${ROJO}${NEGRITO}[✗] $2${SEMCOR}" ;;
        -ama) echo -e "${AMARILLO}${NEGRITO}[!] $2${SEMCOR}" ;;
        -info) echo -e "${CIAN}${NEGRITO}[ℹ] $2${SEMCOR}" ;;
        -azu) echo -e "${AZUL}${NEGRITO} $2${SEMCOR}" ;;
        *) echo -e "$1" ;;
    esac
}

# ============ EXTENDED: JSON HELPERS ============
bm_json_init() {
    mkdir -p "${BM_DATA}" 2>/dev/null || true
    for f in users.json backends.json domains.json traffic.json logs.json settings.json payments.json resellers.json stats.json; do
        [ ! -f "${BM_DATA}/${f}" ] && echo "[]" > "${BM_DATA}/${f}"
        [ ! -s "${BM_DATA}/${f}" ] && echo "[]" > "${BM_DATA}/${f}"
    done
}

bm_log_event() {
    local action="$1" details="$2" ts
    ts="$(date -Iseconds)"
    bm_json_init
    if command -v jq >/dev/null 2>&1; then
        local entry
        entry="$(jq -n --arg t "$ts" --arg a "$action" --arg d "$details" '{timestamp:$t,action:$a,details:$d}')"
        jq ". += [${entry}]" "${BM_LOGS}" > "${BM_LOGS}.tmp" 2>/dev/null && mv "${BM_LOGS}.tmp" "${BM_LOGS}"
    fi
}

bm_sync_txt_to_json() {
    bm_json_init
    command -v jq >/dev/null 2>&1 || return
    local now tmp
    now="$(date +%s)"
    tmp="/tmp/bm_bk_$$.json"
    echo "[]" > "$tmp"
    if [ -f "$USER_DATA" ] && [ -s "$USER_DATA" ]; then
        while IFS=: read -r name ip port exp; do
            [ -z "$name" ] && continue
            local status="active"
            local exp_ts=0
            if [[ "$exp" =~ ^[0-9]+$ ]]; then
                exp_ts="$exp"
                [ "$now" -gt "$exp_ts" ] && status="expired"
            else
                status="corrupt"
            fi
            local obj
            obj="$(jq -n --arg n "$name" --arg i "$ip" --arg p "${port:-80}" --arg s "$status" --argjson e "${exp_ts:-0}" \
                '{name:$n,ip:$i,port:$p,target:($i+":"+$p),status:$s,expires_at:$e}')"
            jq ". += [${obj}]" "$tmp" > "${tmp}.2" && mv "${tmp}.2" "$tmp"
        done < "$USER_DATA"
    fi
    mv "$tmp" "${BM_BACKENDS}" 2>/dev/null || true
}

bm_sync_domains() {
    bm_json_init
    command -v jq >/dev/null 2>&1 || return
    local tmp="/tmp/bm_dom_$$.json"
    echo "[]" > "$tmp"
    for file in /etc/nginx/sites-enabled/*; do
        [ -f "$file" ] || continue
        [ "$(basename "$file")" = "default" ] && continue
        local d
        d="$(grep -h server_name "$file" 2>/dev/null | head -1 | awk '{print $2}' | tr -d ';')"
        if [ -n "$d" ] && [ "$d" != "_" ]; then
            local obj
            obj="$(jq -n --arg d "$d" --arg f "$(basename "$file")" '{domain:$d,file:$f,status:"active"}')"
            jq ". += [${obj}]" "$tmp" > "${tmp}.2" && mv "${tmp}.2" "$tmp"
        fi
    done
    mv "$tmp" "${BM_DOMAINS}" 2>/dev/null || true
}

bm_update_traffic() {
    bm_json_init
    command -v jq >/dev/null 2>&1 || return
    [ ! -f "${BM_TRAFFIC_LOG}" ] || [ ! -s "${BM_TRAFFIC_LOG}" ] && return
    local tmp="/tmp/bm_tr_$$.json"
    local raw="/tmp/bm_tr_$$.raw"
    awk -F'|' 'NF>=4{b=$3;s=$4+0;r=$5+0;if(b==""||b=="-")b="(directo)";sum[b]+=s+r}END{for(b in sum)printf "%s %d\n",b,sum[b]}' \
        "${BM_TRAFFIC_LOG}" 2>/dev/null | sort -k2 -nr > "$raw"
    echo "[]" > "$tmp"
    while read -r bname bbytes; do
        [ -z "$bname" ] && continue
        local obj
        obj="$(jq -n --arg n "$bname" --argjson b "${bbytes:-0}" '{name:$n,bytes:$b}')"
        jq ". += [${obj}]" "$tmp" > "${tmp}.2" && mv "${tmp}.2" "$tmp"
    done < "$raw"
    mv "$tmp" "${BM_TRAFFIC}" 2>/dev/null || true
    rm -f "$raw" 2>/dev/null || true
}

# ============ FUNCIONES AUXILIARES ORIGINALES ============
format_bytes() {
    local bytes=$1
    if ! [[ "$bytes" =~ ^[0-9]+$ ]]; then echo "0 B"; return; fi
    if [ $bytes -ge 1099511627776 ]; then
        awk -v b=$bytes 'BEGIN {printf "%.2f TB", b/1099511627776}'
    elif [ $bytes -ge 1073741824 ]; then
        awk -v b=$bytes 'BEGIN {printf "%.2f GB", b/1073741824}'
    elif [ $bytes -ge 1048576 ]; then
        awk -v b=$bytes 'BEGIN {printf "%.2f MB", b/1048576}'
    elif [ $bytes -ge 1024 ]; then
        awk -v b=$bytes 'BEGIN {printf "%.2f KB", b/1024}'
    else
        echo "${bytes} B"
    fi
}

get_active_domains() {
    local domains=""
    for file in /etc/nginx/sites-enabled/*; do
        if [ -f "$file" ] && [ "$(basename "$file")" != "default" ];
        then
            domain=$(grep -h server_name "$file" | head -1 | awk '{print $2}' | tr -d ';')
            if [ -n "$domain" ] && [ "$domain" != "_" ]; then
                domains="$domains $domain"
            fi
        fi
    done
    if [ -z "$domains" ]; then echo "ninguno"; else echo "$domains"; fi
}

count_backends() {
    if [ -f "$USER_DATA" ]; then wc -l < "$USER_DATA" 2>/dev/null || echo 0; else echo 0; fi
}

last_backup() {
    local latest=$(ls -t "$BACKUP_DIR"/backends_*.tar.gz 2>/dev/null | head -1)
    if [ -n "$latest" ]; then
        local fecha=$(stat -c '%y' "$latest" 2>/dev/null | cut -d. -f1 | cut -d' ' -f1,2)
        echo "SI ($fecha)"
    else
        echo "NO"
    fi
}

draw_bar() {
    local percent=$1 width=20
    local filled=$(echo "$percent * $width / 100" | bc 2>/dev/null || echo 0)
    filled=$(printf "%.0f" "$filled" 2>/dev/null || echo 0)
    [ $filled -gt $width ] && filled=$width
    local empty=$((width - filled)) bar=""
    if [ $percent -ge 80 ]; then bar="${ROJO}"
    elif [ $percent -ge 50 ]; then bar="${AMARILLO}"
    else bar="${VERDE}"; fi
    for ((i=0; i<filled; i++)); do bar="${bar}█"; done
    bar="${bar}${SEMCOR}"
    for ((i=0; i<empty; i++)); do bar="${bar}░"; done
    echo -e "$bar"
}

# ============ PANEL DE ESTADO SUPERIOR (ENHANCED) ============
show_status_panel() {
    clear
    echo -e "${TURQUESA}════════════════════════════════════════════════════════${SEMCOR}"
    echo -e "\E[41;1;37m      🔥 BACKEND MANAGER by JOHNNY (@Jrcelulares) 🔥     \E[0m"
    echo -e "${TURQUESA}════════════════════════════════════════════════════════${SEMCOR}"

    local fecha=$(date '+%d/%m/%Y %H:%M:%S')
    local ip=$(curl -s --max-time 3 ifconfig.me 2>/dev/null || echo "N/D")
    echo -e "${CIAN}📅 FECHA:${SEMCOR} $fecha     ${CIAN}🌐 IP:${SEMCOR} $ip"
    echo -e "${CIAN}════════════════════════════════════════════════════════${SEMCOR}"

    local nginx_status=$(systemctl is-active nginx 2>/dev/null || echo "unknown")
    if [ "$nginx_status" = "active" ]; then nginx_status="${VERDE}✅ ACTIVO${SEMCOR}"; else nginx_status="${ROJO}❌ INACTIVO${SEMCOR}"; fi

    local api_tag="${ROJO}OFF${SEMCOR}"
    curl -s --max-time 1 http://127.0.0.1:5000/api/status >/dev/null 2>&1 && api_tag="${VERDE}ON${SEMCOR}"

    local domain_count=0 first_domain="ninguno" domain_list=""
    for file in /etc/nginx/sites-enabled/*; do
        if [ -f "$file" ] && [ "$(basename "$file")" != "default" ]; then
            domain=$(grep -h server_name "$file" | head -1 | awk '{print $2}' | tr -d ';')
            if [ -n "$domain" ] && [ "$domain" != "_" ]; then
                domain_count=$((domain_count + 1))
                domain_list="$domain_list $domain"
                [ "$first_domain" = "ninguno" ] && first_domain="$domain"
            fi
        fi
    done

    local backends_count=$(count_backends)
    echo -e "🔧 Nginx: $nginx_status  ${CIAN}📦 Dom:${SEMCOR} $domain_count  ${CIAN}🔙 Back:${SEMCOR} $backends_count  ${CIAN}🧩 API:${SEMCOR} $api_tag"
    echo -e "📌 Madre: ${VERDE}$first_domain${SEMCOR}  ${CIAN}📋${SEMCOR}$domain_list"
    echo -e "💾 Backup: $(last_backup)"
    echo -e "${CIAN}════════════════════════════════════════════════════════${SEMCOR}"

    local disk_total=$(df -BG / | awk 'NR==2{print $2}' | sed 's/G//')
    local disk_used=$(df -BG / | awk 'NR==2{print $3}' | sed 's/G//')
    local disk_percent=$(df -h / | awk 'NR==2{print $5}' | sed 's/%//')
    echo -e "💾 DISCO: [$(draw_bar $disk_percent)] ${disk_used}GB/${disk_total}GB (${disk_percent}%)"

    local mem_line=$(free -m | grep Mem:)
    local mem_total=$(echo $mem_line | awk '{print $2}')
    local mem_used=$(echo $mem_line | awk '{print $3}')
    local mem_percent=$((mem_used * 100 / mem_total))
    echo -e "🧠 RAM:   [$(draw_bar $mem_percent)] ${mem_used}MB/${mem_total}MB (${mem_percent}%)"

    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    [ -z "$cpu_usage" ] && cpu_usage=0
    local cpu_percent=$(printf "%.0f" "$cpu_usage" 2>/dev/null || echo 0)
    local load=$(uptime | awk -F'load average:' '{print $2}' | xargs)
    echo -e "⚡ CPU:   [$(draw_bar $cpu_percent)] ${cpu_usage}% (load $load)"

    local iface=$(ip route | grep default | awk '{print $5}' | head -1)
    if [ -n "$iface" ] && [ -r /proc/net/dev ]; then
        local line=$(grep "$iface:" /proc/net/dev)
        local rx_bytes=$(echo $line | awk '{print $2}')
        local tx_bytes=$(echo $line | awk '{print $10}')
        echo -e "🌐 RED:  ${VERDE}📥 $(format_bytes $rx_bytes)${SEMCOR}  |  ${AMARILLO}📤 $(format_bytes $tx_bytes)${SEMCOR}"
    fi

    # Sync JSON silencioso
    bm_sync_txt_to_json >/dev/null 2>&1 || true
    bm_sync_domains >/dev/null 2>&1 || true
    echo -e "${CIAN}════════════════════════════════════════════════════════${SEMCOR}"
}

# ============ FUNCIONES ORIGINALES CORE ============
check_and_clean_expired() {
    local modified=0 current_time=$(date +%s)
    [ ! -f "$USER_DATA" ] || [ ! -s "$USER_DATA" ] && return
    msg -info "🔍 Verificando backends expirados..."
    awk -v current="$current_time" -F: '{
        if ($4 ~ /^[0-9]+$/) { if (current > $4) print "EXPIRADO:" $0; else print "VIGENTE:" $0 }
        else print "CORRUPTO:" $0
    }' "$USER_DATA" > /tmp/user_data_analysis.tmp
    grep "^VIGENTE:" /tmp/user_data_analysis.tmp | sed 's/^VIGENTE://' > /tmp/user_data_new.tmp
    local expirados=$(grep "^EXPIRADO:" /tmp/user_data_analysis.tmp | sed 's/^EXPIRADO://')
    local corruptos=$(grep "^CORRUPTO:" /tmp/user_data_analysis.tmp | sed 's/^CORRUPTO://')
    if [ -n "$expirados" ] || [ -n "$corruptos" ]; then
        echo "$expirados" | cut -d: -f1 > /tmp/names_to_delete.tmp
        echo "$corruptos" | cut -d: -f1 >> /tmp/names_to_delete.tmp
        awk 'BEGIN{while(getline name < "/tmp/names_to_delete.tmp"){dn[name]=1}s=0}
        /# BACKEND /{for(n in dn){if($0~"# BACKEND "n){s=3;print "ELIMINADO: "$0>"/dev/stderr";next}}}
        /if \$\$http_backend = /{if(s>0){s--;next}for(n in dn){if($0~"\\$http_backend = \""n"\""){s=2;print "ELIMINADO: "$0>"/dev/stderr";next}}}
        {if(s>0){s--}else{print}}' "$BACKEND_CONF" > /tmp/nginx_conf_new.tmp 2>/tmp/deleted_lines.tmp
        [ -s /tmp/deleted_lines.tmp ] && modified=1
        if [ -n "$expirados" ]; then
            echo "$expirados" | while IFS=: read -r name ip port exp; do
                msg -verm "  ⏰ EXPIRADO: ${name} → ${ip}:${port}"
            done
        fi
    fi
    [ -f /tmp/user_data_new.tmp ] && mv /tmp/user_data_new.tmp "$USER_DATA"
    [ -f /tmp/nginx_conf_new.tmp ] && mv /tmp/nginx_conf_new.tmp "$BACKEND_CONF"
    if [ $modified -eq 1 ]; then
        if /usr/sbin/nginx -t 2>/dev/null; then
            systemctl reload nginx
            msg -verd "✅ Backends expirados eliminados"
            bm_log_event "CLEAN_EXPIRED" "Backends expirados limpiados"
        fi
    else
        msg -verd "✅ No hay backends expirados"
    fi
    rm -f /tmp/user_data_analysis.tmp /tmp/user_data_new.tmp /tmp/nginx_conf_new.tmp /tmp/names_to_delete.tmp /tmp/deleted_lines.tmp
    bm_sync_txt_to_json >/dev/null 2>&1 || true
}

add_backend_minutes() {
    show_status_panel
    msg -bar
    msg -verd "AGREGAR BACKEND CON EXPIRACIÓN EN MINUTOS"
    msg -bar
    [ ! -f "$USER_DATA" ] && touch "$USER_DATA"
    while true; do
        read -p "Nombre del backend: " bname
        bname=$(echo "$bname" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
        if [ -z "$bname" ]; then msg -verm "Nombre vacío"
        elif grep -q "^${bname}:" "$USER_DATA" 2>/dev/null; then msg -verm "Ya existe"
        else break; fi
    done
    read -p "IP o dominio destino: " bip
    [ -z "$bip" ] && { msg -verm "IP vacía"; sleep 2; return; }
    read -p "Puerto (80): " bport; bport=${bport:-80}
    while true; do
        read -p "Minutos de expiración: " minutes
        [[ "$minutes" =~ ^[0-9]+$ ]] && [ "$minutes" -gt 0 ] && break
        msg -verm "Número positivo requerido"
    done
    local exp_date=$(date -d "+${minutes} minutes" '+%d/%m/%Y %H:%M')
    local block_comment="# BACKEND ${bname} - Creado: $(date '+%d/%m/%Y %H:%M') - Expira: ${exp_date}"
    sed -i "/# SOPORTE PARA USUARIOS PERSONALIZADOS/i \ \n    ${block_comment}\n    if (\$http_backend = \"$bname\") {\n        set \$target_backend \"http://${bip}:${bport}\";\n    }" "$BACKEND_CONF"
    local now=$(date +%s)
    local expiration_date=$((now + (minutes * 60)))
    echo "${bname}:${bip}:${bport}:${expiration_date}" >> "$USER_DATA"
    msg -verd "✅ BACKEND ${bname} agregado!"
    msg -info "IP: ${bip}:${bport} - Expira: ${exp_date}"
    /usr/sbin/nginx -t && systemctl reload nginx && msg -verd "Nginx recargado!"
    bm_log_event "BACKEND_CREATED" "Backend ${bname} → ${bip}:${bport} (${minutes}min)"
    bm_sync_txt_to_json >/dev/null 2>&1 || true
    msg -bar; read -p "Presiona ENTER..."
}

add_backend_days() {
    show_status_panel
    msg -bar
    msg -verd "AGREGAR BACKEND CON EXPIRACIÓN EN DÍAS"
    msg -bar
    [ ! -f "$USER_DATA" ] && touch "$USER_DATA"
    while true; do
        read -p "Nombre del backend: " bname
        bname=$(echo "$bname" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
        if [ -z "$bname" ]; then msg -verm "Nombre vacío"
        elif grep -q "^${bname}:" "$USER_DATA" 2>/dev/null; then msg -verm "Ya existe"
        else break; fi
    done
    read -p "IP o dominio destino: " bip
    [ -z "$bip" ] && { msg -verm "IP vacía"; sleep 2; return; }
    read -p "Puerto (80): " bport; bport=${bport:-80}
    while true; do
        read -p "Días de expiración: " days
        [[ "$days" =~ ^[0-9]+$ ]] && [ "$days" -gt 0 ] && break
        msg -verm "Número positivo requerido"
    done
    local exp_date=$(date -d "+${days} days" '+%d/%m/%Y')
    local block_comment="# BACKEND ${bname} - Creado: $(date '+%d/%m/%Y') - Expira: ${exp_date}"
    sed -i "/# SOPORTE PARA USUARIOS PERSONALIZADOS/i \ \n    ${block_comment}\n    if (\$http_backend = \"$bname\") {\n        set \$target_backend \"http://${bip}:${bport}\";\n    }" "$BACKEND_CONF"
    local now=$(date +%s)
    local expiration_date=$((now + (days * 86400)))
    echo "${bname}:${bip}:${bport}:${expiration_date}" >> "$USER_DATA"
    msg -verd "✅ BACKEND ${bname} agregado!"
    msg -info
        msg -info "IP: ${bip}:${bport} - Expira: ${exp_date} (${days} días)"
    /usr/sbin/nginx -t && systemctl reload nginx && msg -verd "Nginx recargado!"
    bm_log_event "BACKEND_CREATED" "Backend ${bname} → ${bip}:${bport} (${days}d)"
    bm_sync_txt_to_json >/dev/null 2>&1 || true
    msg -bar; read -p "Presiona ENTER..."
}

init_system() {
    mkdir -p "$BACKUP_DIR"
    touch "$USER_DATA"
    bm_json_init
    if ! command -v nginx &>/dev/null; then
        msg -ama "NGINX no instalado. Usa opción 1."
    fi
}

backup_backends() {
    show_status_panel
    msg -tit "RESPALDO DE BACKENDS"
    mkdir -p "$BACKUP_DIR"
    local fecha=$(date '+%Y%m%d_%H%M%S')
    local backup_file="${BACKUP_DIR}/backends_${fecha}.tar.gz"
    if [ -f "$USER_DATA" ] || [ -f "$BACKEND_CONF" ]; then
        tar -czf "$backup_file" "$USER_DATA" "$BACKEND_CONF" 2>/dev/null
        if [ $? -eq 0 ]; then
            msg -verd "✅ RESPALDO CREADO!"
            msg -info "Archivo: backends_${fecha}.tar.gz"
            bm_log_event "BACKUP" "Backup creado: ${backup_file}"
        else
            msg -verm "Error al crear respaldo"
        fi
    else
        msg -ama "No hay archivos para respaldar"
    fi
    msg -bar; read -p "Presiona ENTER..."
}

restore_backends() {
    show_status_panel
    msg -tit "RESTAURACIÓN DE BACKENDS"
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A $BACKUP_DIR 2>/dev/null)" ]; then
        msg -ama "No hay backups disponibles"
        msg -bar; read -p "Presiona ENTER..."; return
    fi
    local i=1; declare -a backup_files
    while read -r backup; do
        [ -n "$backup" ] && { echo -e "${VERDE}${i})${SEMCOR} ${backup}"; backup_files[$i]="$backup"; i=$((i+1)); }
    done < <(ls -1 "$BACKUP_DIR" | grep 'backends_.*\.tar\.gz$' | sort -r)
    [ $i -eq 1 ] && { msg -ama "Sin backups válidos"; msg -bar; read -p "Presiona ENTER..."; return; }
    read -p "Número del backup (0=cancelar): " backup_num
    [ "$backup_num" = "0" ] && return
    if [[ "$backup_num" =~ ^[0-9]+$ ]] && [ "$backup_num" -ge 1 ] && [ "$backup_num" -lt "$i" ]; then
        local selected="${backup_files[$backup_num]}"
        read -p "Escribe RESTAURAR para confirmar: " confirm
        if [ "$confirm" = "RESTAURAR" ]; then
            tar -czf "${BACKUP_DIR}/pre_restore_$(date +%Y%m%d_%H%M%S).tar.gz" "$USER_DATA" "$BACKEND_CONF" 2>/dev/null
            tar -xzf "$BACKUP_DIR/$selected" -C / 2>/dev/null
            /usr/sbin/nginx -t && systemctl reload nginx
            msg -verd "✅ RESTAURACIÓN COMPLETADA!"
            bm_log_event "RESTORE" "Restaurado desde: ${selected}"
        fi
    fi
    msg -bar; read -p "Presiona ENTER..."
}

list_backups() {
    show_status_panel
    msg -tit "LISTA DE BACKUPS"
    if [ -d "$BACKUP_DIR" ]; then
        ls -1 "$BACKUP_DIR" | grep 'backends_.*\.tar\.gz$' | sort -r | while read -r b; do
            local fecha=$(stat -c '%y' "$BACKUP_DIR/$b" 2>/dev/null | cut -d. -f1)
            echo -e "${VERDE}•${SEMCOR} ${b}  ${CIAN}(${fecha})${SEMCOR}"
        done
    else
        msg -ama "No hay backups"
    fi
    msg -bar; read -p "Presiona ENTER..."
}

clean_old_backups() {
    show_status_panel
    msg -tit "LIMPIAR BACKUPS ANTIGUOS"
    echo "1) Mantener últimos 5"
    echo "2) Mantener últimos 10"
    echo "3) Eliminar +30 días"
    echo "4) Eliminar todos"
    echo "0) Cancelar"
    read -p "Opción: " co
    case $co in
        1) ls -t "$BACKUP_DIR"/backends_*.tar.gz 2>/dev/null | tail -n +6 | xargs rm -f; msg -verd "Limpieza OK" ;;
        2) ls -t "$BACKUP_DIR"/backends_*.tar.gz 2>/dev/null | tail -n +11 | xargs rm -f; msg -verd "Limpieza OK" ;;
        3) find "$BACKUP_DIR" -name "backends_*.tar.gz" -mtime +30 -delete; msg -verd "Limpieza OK" ;;
        4) read -p "Escribe ELIMINAR: " c; [ "$c" = "ELIMINAR" ] && rm -f "$BACKUP_DIR"/backends_*.tar.gz ;;
        0) return ;;
    esac
    msg -bar; read -p "Presiona ENTER..."
}

backup_menu() {
    while true; do
        show_status_panel
        msg -tit "GESTIÓN DE BACKUPS"
        echo -e "${VERDE}  [1]${SEMCOR} Crear backup"
        echo -e "${VERDE}  [2]${SEMCOR} Restaurar backup"
        echo -e "${VERDE}  [3]${SEMCOR} Listar backups"
        echo -e "${VERDE}  [4]${SEMCOR} Limpiar antiguos"
        echo -e "${VERDE}  [0]${SEMCOR} Volver"
        read -p "Opción: " bo
        case $bo in
            1) backup_backends ;; 2) restore_backends ;; 3) list_backups ;; 4) clean_old_backups ;; 0) return ;; *) msg -verm "Inválido"; sleep 1 ;;
        esac
    done
}

install_nginx_super() {
    show_status_panel
    msg -tit "INSTALACIÓN PROFESIONAL NGINX"
    ss -tlnp | grep -q ':80 ' && { systemctl stop apache2 2>/dev/null; systemctl disable apache2 2>/dev/null; fuser -k 80/tcp 2>/dev/null; }
    apt update -y; apt install nginx -y
    cat > "$BACKEND_CONF" <<'INNER'
server {
    listen 80;
    listen [::]:80;
    server_name _;
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    proxy_connect_timeout 86400s;
    proxy_send_timeout 86400s;
    proxy_read_timeout 86400s;
    set $target_backend "http://127.0.0.1:8080";
    if ($http_backend) { set $target_backend "http://$http_backend"; }
    if ($http_backend = "local") { set $target_backend "http://127.0.0.1:8080"; }
    if ($http_backend = "ssh") { set $target_backend "http://127.0.0.1:22"; }
    # SOPORTE PARA USUARIOS PERSONALIZADOS
    if ($http_user) { set $target_backend "http://$http_user"; }
    location / {
        proxy_pass $target_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_cache off;
        proxy_buffering off;
    }
    location /nginx_status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        deny all;
    }
}
INNER
    ln -sf "$BACKEND_CONF" "$BACKEND_ENABLED"
    rm -f /etc/nginx/sites-enabled/default
    if /usr/sbin/nginx -t; then
        systemctl restart nginx
        msg -verd "NGINX instalado y configurado!"
        bm_log_event "NGINX_INSTALL" "Nginx instalado con config dinámica"
    else
        msg -verm "Error en configuración"
    fi
    msg -bar; read -p "Presiona ENTER..."
}

install_python_proxy() {
    local script_url="https://raw.githubusercontent.com/vpsnet360/instalador/refs/heads/main/so"
    local script_path="/etc/so"
    wget -q -O "$script_path" "$script_url"
    if [[ $? -ne 0 || ! -s "$script_path" ]]; then
        echo -e "\033[1;31mError: No se pudo descargar.\033[0m"; return
    fi
    chmod +x "$script_path"
    "$script_path"
}

manage_backends() {
    show_status_panel
    msg -tit "GESTIÓN DE BACKENDS PERSONALIZADOS"
    echo -e "${CIAN}BACKENDS ACTUALES:${SEMCOR}"
    msg -bar
    if [ -f "$USER_DATA" ] && [ -s "$USER_DATA" ]; then
        while IFS=: read -r user ip port exp_time; do
            if [[ "$exp_time" =~ ^[0-9]+$ ]]; then
                local current_time=$(date +%s)
                if [ $current_time -gt $exp_time ]; then
                    echo -e "${ROJO}⚠️ ${user} → ${ip}:${port} (EXPIRADO)${SEMCOR}"
                else
                    local days_left=$(( (exp_time - current_time) / 86400 ))
                    local hours_left=$(( ((exp_time - current_time) % 86400) / 3600 ))
                    local mins_left=$(( ((exp_time - current_time) % 3600) / 60 ))
                    if [ $days_left -gt 0 ]; then
                        echo -e "${VERDE}✅ ${user} → ${ip}:${port} (${days_left}d restantes)${SEMCOR}"
                    elif [ $hours_left -gt 0 ]; then
                        echo -e "${AMARILLO}⚠️ ${user} → ${ip}:${port} (${hours_left}h ${mins_left}m)${SEMCOR}"
                    else
                        echo -e "${AMARILLO}⚠️ ${user} → ${ip}:${port} (${mins_left}m)${SEMCOR}"
                    fi
                fi
            fi
        done < "$USER_DATA"
    else
        echo -e "${AMARILLO}  Sin backends personalizados${SEMCOR}"
    fi
    msg -bar
    echo -e "${VERDE}🔧 LOCAL → 127.0.0.1:8080 (Fijo)${SEMCOR}"
    echo -e "${VERDE}🔧 SSH → 127.0.0.1:22 (Fijo)${SEMCOR}"
    msg -bar2
    echo -e "${AMARILLO}1) Agregar (DÍAS)     5) Probar conectividad"
    echo -e "2) Agregar (MINUTOS)  6) Extender expiración"
    echo -e "3) Editar existente   7) Limpiar expirados"
    echo -e "4) Eliminar backend   0) Volver${SEMCOR}"
    msg -bar
    read -p "🔥 Opción: " bo
    case $bo in
        1) add_backend_days ;;
        2) add_backend_minutes ;;
        3)
            read -p "Backend a editar: " bname
            nano "$BACKEND_CONF"
            read -p "¿Actualizar expiración? (s/n): " ue
            if [[ "$ue" =~ ^[sS]$ ]]; then
                read -p "Nuevos días: " nd
                if [[ "$nd" =~ ^[0-9]+$ ]] && [ "$nd" -gt 0 ]; then
                    local cd=$(grep "^${bname}:" "$USER_DATA")
                    local ci=$(echo "$cd"|cut -d: -f2) cp=$(echo "$cd"|cut -d: -f3)
                    local ne=$(( $(date +%s) + (nd * 86400) ))
                    sed -i "s/^${bname}:.*/${bname}:${ci}:${cp}:${ne}/" "$USER_DATA"
                    msg -verd "Expiración actualizada!"
                fi
            fi ;;
        4)
            read -p "Backend a eliminar: " bname
            read -p "¿Seguro? (s/n): " confirm
            if [[ "$confirm" =~ ^[sS]$ ]]; then
                grep -v "^${bname}:" "$USER_DATA" > /tmp/ud_new && mv /tmp/ud_new "$USER_DATA"
                grep -v "# BACKEND ${bname}" "$BACKEND_CONF" | grep -v "\$http_backend = \"$bname\"" > /tmp/nc_new && mv /tmp/nc_new "$BACKEND_CONF"
                /usr/sbin/nginx -t && systemctl reload nginx
                msg -verd "✅ ${bname} eliminado!"
                bm_log_event "BACKEND_DELETED" "Backend ${bname} eliminado"
            fi ;;
        5)
            if [ -f "$USER_DATA" ] && [ -s "$USER_DATA" ]; then
                while IFS=: read -r bn bi bp be; do
                    if curl -s --connect-timeout 2 "http://${bi}:${bp}" >/dev/null; then
                        msg -verd "✓ ${bn} (${bi}:${bp}) OK"
                    else
                        msg -verm "✗ ${bn} (${bi}:${bp}) FALLO"
                    fi
                done < "$USER_DATA"
            fi ;;
        6)
            if [ -f "$USER_DATA" ] && [ -s "$USER_DATA" ]; then
                local i=1; declare -a vb
                while IFS=: read -r bn bi bp be; do
                    [[ "$be" =~ ^[0-9]+$ ]] || continue
                    local ed=$(date -d "@$be" '+%d/%m/%Y %H:%M' 2>/dev/null)
                    echo -e "${VERDE}${i
                    })${SEMCOR} ${bn} - ${bi}:${bp} - Exp: ${ed}"
                    vb[$i]="$bn"; i=$((i+1))
                done < "$USER_DATA"
                if [ $i -gt 1 ]; then
                    read -p "Número del backend: " bnum
                    if [[ "$bnum" =~ ^[0-9]+$ ]] && [ "$bnum" -lt "$i" ]; then
                        local bs="${vb[$bnum]}"
                        read -p "Minutos adicionales: " em
                        if [[ "$em" =~ ^[0-9]+$ ]] && [ "$em" -gt 0 ]; then
                            local od=$(grep "^${bs}:" "$USER_DATA")
                            local oi=$(echo "$od"|cut -d: -f2) op=$(echo "$od"|cut -d: -f3) oe=$(echo "$od"|cut -d: -f4)
                            local ne=$((oe + (em * 60)))
                            sed -i "s/^${bs}:.*/${bs}:${oi}:${op}:${ne}/" "$USER_DATA"
                            local ned=$(date -d "@$ne" '+%d/%m/%Y %H:%M')
                            sed -i "s|# BACKEND ${bs}.*|# BACKEND ${bs} - Extendido: $(date '+%d/%m/%Y %H:%M') - Expira: ${ned}|" "$BACKEND_CONF"
                            msg -verd "Extendido! Nueva exp: ${ned}"
                            bm_log_event "BACKEND_EXTENDED" "${bs} extendido +${em}min"
                        fi
                    fi
                fi
            fi ;;
        7) check_and_clean_expired ;;
        0) return ;;
    esac
    bm_sync_txt_to_json >/dev/null 2>&1 || true
    if [ "$bo" != "5" ] && [ "$bo" != "7" ] && [ "$bo" != "0" ]; then
        /usr/sbin/nginx -t 2>/dev/null && systemctl reload nginx
    fi
    msg -bar; read -p "Presiona ENTER..."
}

show_epic_instructions() {
    show_status_panel
    msg -tit "INSTRUCCIONES Y PAYLOADS"
    echo -e "${VERDE}🔥 BACKEND LOCAL:${SEMCOR}"
    echo -e "GET / HTTP/1.1[crlf]\nHost: tudominio.com[crlf]\nBackend: local[crlf]\nConnection: Upgrade[crlf]\nUpgrade: websocket[crlf][crlf]"
    echo -e "\n${AMARILLO}🔥 BACKEND REMOTO:${SEMCOR}"
    echo -e "GET / HTTP/1.1[crlf]\nHost: tudominio.com[crlf]\nBackend: sv1[crlf]\nConnection: Upgrade[crlf]\nUpgrade: websocket[crlf][crlf]"
    echo -e "\n${MORADO}🔥 IP DIRECTA:${SEMCOR}"
    echo -e "GET / HTTP/1.1[crlf]\nHost: tudominio.com[crlf]\nBackend: 192.168.1.100:80[crlf]\nConnection: Upgrade[crlf]\nUpgrade: websocket[crlf][crlf]"
    echo -e "\n${VERDE}COMANDOS ÚTILES:${SEMCOR}"
    echo -e "  Logs: ${CIAN}tail -f /var/log/nginx/access.log${SEMCOR}"
    echo -e "  Estado: ${CIAN}systemctl status nginx${SEMCOR}"
    echo -e "  Dashboard: ${CIAN}http://TU_IP:8081${SEMCOR}"
    echo -e "  API: ${CIAN}curl http://127.0.0.1:5000/api/status${SEMCOR}"
    msg -bar; read -p "Presiona ENTER..."
}

show_status() {
    show_status_panel
    msg -tit "ESTADO DEL SISTEMA"
    systemctl is-active --quiet nginx && msg -verd "NGINX: ACTIVO ✅" || msg -verm "NGINX: INACTIVO ❌"
    systemctl is-active --quiet backend-manager-api && msg -verd "API Flask: ACTIVO ✅" || msg -verm "API Flask: INACTIVO ❌"
    systemctl is-active --quiet superc4mpeon-proxy && msg -verd "Proxy Python: ACTIVO ✅" || msg -verm "Proxy Python: INACTIVO ❌"
    msg -info "Puertos en escucha:"
    ss -tlnp | grep -E ':(80|5000|8080|8081|22) ' | column -t
    msg -info "Conexiones activas Nginx:"
    ss -tn state established '( dport = :80 or sport = :80 )' | tail -n +2 | wc -l | xargs echo "  Total:"
    msg -bar; read -p "Presiona ENTER..."
}

uninstall_everything() {
    show_status_panel
    msg -tit "DESINSTALACIÓN COMPLETA"
    msg -verm "⚠️  ESTO ELIMINARÁ TODO ⚠️"
    read -p "Escribe SI para confirmar: " confirm
    if [ "$confirm" = "SI" ]; then
        systemctl stop backend-manager-api superc4mpeon-proxy nginx 2>/dev/null
        systemctl disable backend-manager-api superc4mpeon-proxy nginx 2>/dev/null
        apt purge nginx nginx-common -y
        apt autoremove -y
        rm -rf /etc/nginx/superc4mpeon* /etc/backend-manager /var/www/backend-manager
        rm -f /etc/systemd/system/backend-manager-api.service
        systemctl daemon-reload
        read -p "¿Eliminar backups? (s/n): " db
        [[ "$db" =~ ^[sS]$ ]] && rm -rf "$BACKUP_DIR" /root/backend-backups
        msg -verd "Desinstalación completa!"
        bm_log_event "UNINSTALL" "Sistema desinstalado completamente"
    fi
    msg -bar; read -p "Presiona ENTER..."
}

# ============ FUNCIONES ORIGINALES EXTRA ============
healthcheck() {
    show_status_panel
    msg -tit "HEALTHCHECK DE BACKENDS"
    if [ -f "$USER_DATA" ] && [ -s "$USER_DATA" ]; then
        while IFS=: read -r name ip port exp; do
            echo -n "  $name ($ip:$port)... "
            if curl -s --connect-timeout 2 "http://$ip:$port" >/dev/null; then
                local lat=$(curl -o /dev/null -s -w '%{time_total}' "http://$ip:$port" 2>/dev/null)
                echo -e "${VERDE}OK (${lat}s)${SEMCOR}"
            else
                echo -e "${ROJO}FALLO${SEMCOR}"
            fi
        done < "$USER_DATA"
    else
        msg -ama "No hay backends"
    fi
    read -p "Presiona ENTER..."
}

validate_connection() {
    show_status_panel
    msg -tit "VALIDAR CONEXIÓN CON HEADER"
    read -p "Dominio madre: " domain
    read -p "Backend (nombre o IP:puerto): " backend
    curl -H "Backend: $backend" -H "Host: $domain" http://127.0.0.1 -v 2>&1 | grep -E "< HTTP/|< Location|Connected"
    read -p "Presiona ENTER..."
}

edit_timeouts() {
    show_status_panel
    read -p "Archivo de config: " domain
    [ -f "/etc/nginx/sites-available/$domain" ] && nano "/etc/nginx/sites-available/$domain" && systemctl reload nginx || msg -verm "No existe"
    read -p "Presiona ENTER..."
}

balanceo() { show_status_panel; msg -tit "BALANCEO DE CARGA"; echo "Edita /etc/nginx/conf.d/upstream.conf manualmente"; read -p "Presiona ENTER..."; }

limit_bandwidth() {
    show_status_panel
    read -p "Backend a limitar: " target
    read -p "Límite KB/s: " rate
    msg -info "Agrega 'limit_rate ${rate}k;' en la config del backend"
    read -p "Presiona ENTER..."
}

ufw_open() {
    show_status_panel
    read -p "Puerto a abrir: " port
    ufw allow $port/tcp; ufw reload
    msg -verd "Puerto $port abierto"
    bm_log_event "UFW" "Puerto $port abierto"
    read -p "Presiona ENTER..."
}

speedtest_run() {
    show_status_panel
    msg -tit "SPEEDTEST"
    command -v speedtest-cli &>/dev/null && speedtest-cli --simple || msg -verm "speedtest-cli no instalado"
    read -p "Presiona ENTER..."
}

maintenance() {
    show_status_panel
    msg -tit "MANTENIMIENTO"
    echo "1) Limpiar expirados ahora"
    echo "2) Programar cron (cada hora)"
    echo "0) Cancelar"
    read -p "Opción: " opt
    case $opt in
        1) check_and_clean_expired ;;
        2) (crontab -l 2>/dev/null; echo "0 * * * * /root/superc4mpeon.sh --clean-expired") | crontab -; msg -verd "Cron añadido" ;;
        0) return ;;
    esac
    read -p "Presiona ENTER..."
}

# ============ FUNCIONES EXTENDED NUEVAS ============
bm_server_monitoring() {
    show_status_panel
    msg -tit "MONITOREO DETALLADO DEL SERVIDOR"
    echo -e "${CIAN}SISTEMA:${SEMCOR}"
    echo "  Hostname: $(hostname)"
    echo "  Kernel:   $(uname -r)"
    echo "  Uptime:   $(uptime -p)"
    echo "  Load:     $(cat /proc/loadavg | cut -d' ' -f1-3)"
    msg -bar2
    echo -e "${CIAN}CPU:${SEMCOR}"
    echo "  Cores:    $(nproc)"
    echo "  Modelo:   $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
    local cu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
    echo "  Uso:      ${cu}%"
    msg -bar2
    echo -e "${CIAN}MEMORIA:${SEMCOR}"
    free -h | grep -E "Mem:|Swap:"
    msg -bar2
    echo -e "${CIAN}DISCO:${SEMCOR}"
    df -h / | tail -1 | awk '{printf "  Total: %s  Usado: %s  Libre: %s  Uso: %s\n",$2,$3,$4,$5}'
    msg -bar2
    echo -e "${CIAN}RED:${SEMCOR}"
    local iface=$(ip route | grep default | awk '{print $5}' | head -1)
    if [ -n "$iface" ]; then
        local line=$(grep "$iface:" /proc/net/dev)
        echo "  Interface: $iface"
        echo "  RX: $(format_bytes $(echo $line | awk '{print $2}'))"
        echo "  TX: $(format_bytes $(echo $line | awk '{print $10}'))"
    fi
    msg -bar; read -p "Presiona ENTER..."
}

bm_backend_monitoring() {
    show_status_panel
    msg -tit "MONITOREO DE BACKENDS"
    bm_sync_txt_to_json >/dev/null 2>&1 || true
    bm_sync_domains >/dev/null 2>&1 || true
    local total=0 activos=0 expirados=0 now=$(date +%s)
    if [ -f "$USER_DATA" ] && [ -s "$USER_DATA" ]; then
        while IFS=: read -r n i p e; do
            total=$((total+1))
            if [[ "$e" =~ ^[0-9]+$ ]] && [ "$now" -gt "$e" ]; then
                expirados=$((expirados+1))
            else
                activos=$((activos+1))
            fi
        done < "$USER_DATA"
    fi
    local dom_count=0
    for f in /etc/nginx/sites-enabled/*; do
        [ -f "$f" ] && [ "$(basename "$f")" != "default" ] && dom_count=$((dom_count+1))
    done
    echo -e "${CIAN}RESUMEN:${SEMCOR}"
    echo -e "  Total backends:    ${BLANCO}${total}${SEMCOR}"
    echo -e "  Activos:           ${VERDE}${activos}${SEMCOR}"
    echo -e "  Expirados:         ${ROJO}${expirados}${SEMCOR}"
    echo -e "  Dominios activos:  ${BLANCO}${dom_count}${SEMCOR}"
    msg -bar2
    echo -e "${CIAN}DETALLE:${SEMCOR}"
    if [ -f "$USER_DATA" ] && [ -s "$USER_DATA" ]; then
        while IFS=: read -r n i p e; do
            local st="${VERDE}ACTIVO${SEMCOR}" tl=""
            if [[ "$e" =~ ^[0-9]+$ ]]; then
                if [ "$now" -gt "$e" ]; then
                    st="${ROJO}EXPIRADO${SEMCOR}"
                else
                    local dl=$(( (e - now) / 86400 )) hl=$(( ((e - now) % 86400) / 3600 ))
                    tl="${dl}d ${hl}h"
                fi
            fi
            echo -e "  ${BLANCO}${n}${SEMCOR} → ${i}:${p}  [$st]  ${tl}"
        done < "$USER_DATA"
    fi
    msg -bar; read -p "Presiona ENTER..."
}

bm_traffic_viewer() {
    show_status_panel
    msg -tit "TRÁFICO POR BACKEND"
    bm_update_traffic >/dev/null 2>&1 || true
    if command -v jq >/dev/null 2>&1 && [ -f "${BM_TRAFFIC}" ] && [ -s "${BM_TRAFFIC}" ]; then
        local count=$(jq length "${BM_TRAFFIC}" 2>/dev/null || echo 0)
        if [ "$count" -gt 0 ]; then
            jq -r '.[]|"\$.name) \$.bytes)"' "${BM_TRAFFIC}" 2>/dev/null | while read -r bname bbytes; do
                echo -e "  ${VERDE}${bname}${SEMCOR} : ${AMARILLO}$(format_bytes ${bbytes:-0})${SEMCOR}"
            done
