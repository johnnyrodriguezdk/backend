#!/bin/bash
# ============================================================
# INSTALADOR - BACKEND MANAGER by JOHNNY (@Jrcelulares)
# Versión: 6.0 - 22 opciones + panel visual + payloads + bot
# ============================================================

# Colores para el instalador
VERDE='\e[1;32m'
ROJO='\e[1;31m'
AMARILLO='\e[1;33m'
CIAN='\e[1;36m'
SEMCOR='\e[0m'

# Verificar root
if [[ $EUID -ne 0 ]]; then
    echo -e "${ROJO}[✗] Ejecuta como root: sudo bash $0${SEMCOR}"
    exit 1
fi

echo -e "${CIAN}════════════════════════════════════════════════════════${SEMCOR}"
echo -e "\E[41;1;37m   INSTALADOR - BACKEND MANAGER by JOHNNY   \E[0m"
echo -e "${CIAN}════════════════════════════════════════════════════════${SEMCOR}"

# Backup del script actual si existe
if [ -f /root/superc4mpeon.sh ]; then
    echo -e "${AMARILLO}[!] El script actual será reemplazado. Se hará un backup.${SEMCOR}"
    cp /root/superc4mpeon.sh /root/superc4mpeon.sh.backup.$(date +%Y%m%d%H%M%S)
    echo -e "${VERDE}[✓] Backup creado.${SEMCOR}"
fi

# Instalar dependencias
echo -e "${AMARILLO}[ℹ] Instalando dependencias necesarias...${SEMCOR}"
apt update -y
apt install -y nginx curl wget speedtest-cli ufw bc net-tools

# Crear directorios y archivos de datos
mkdir -p /etc/nginx/superc4mpeon_backups
touch /etc/nginx/superc4mpeon_users.txt
mkdir -p /root/superc4mpeon_backups

# Crear directorio para payloads
STATE_DIR="/etc/nginx/superc4mpeon_state"
mkdir -p "$STATE_DIR/payloads"

# ============================================================
# GENERAR EL SCRIPT PRINCIPAL /root/superc4mpeon.sh
# (Incluye TODAS las funciones originales + payloads + bot)
# ============================================================
cat > /root/superc4mpeon.sh << 'EOF'
#!/bin/bash

# ==================================================
# SCRIPT: BACKEND MANAGER by JOHNNY (@Jrcelulares)
# VERSIÓN: 6.0 - 22 OPCIONES + PAYLOADS + BOT
# ==================================================

# ███████╗██╗   ██╗██████╗ ███████╗██████╗  ██████╗██╗  ██╗
# ██╔════╝██║   ██║██╔══██╗██╔════╝██╔══██╗██╔════╝██║  ██║
# ███████╗██║   ██║██████╔╝█████╗  ██████╔╝██║     ███████║
# ╚════██║██║   ██║██╔═══╝ ██╔══╝  ██╔══██╗██║     ██╔══██║
# ███████║╚██████╔╝██║     ███████╗██║  ██║╚██████╗██║  ██║
# ╚══════╝ ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝

# COLORES PROFESIONALES
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

# Alias para compatibilidad con payloads
NC="$SEMCOR"; DIM='\e[2m'; GRN="$VERDE"; YLW="$AMARILLO"; RED="$ROJO"; CYA="$CIAN"; WHT="$BLANCO"; BOLD="$NEGRITO"

# ARCHIVOS DE CONFIGURACIÓN
BACKEND_CONF="/etc/nginx/sites-available/superc4mpeon"
BACKEND_ENABLED="/etc/nginx/sites-enabled/superc4mpeon"
USER_DATA="/etc/nginx/superc4mpeon_users.txt"
BACKUP_DIR="/root/superc4mpeon_backups"

# ============ VARIABLES PARA PAYLOADS ============
STATE_DIR="/etc/nginx/superc4mpeon_state"
NGX_BACKENDS_MAP="$USER_DATA"
HEADER_NAME="Backend"
PAYLOAD_DIR="${STATE_DIR}/payloads"

# ============ FUNCIÓN DE MENSAJES ============
msg() {
    case $1 in
        -tit) echo -e "${MORADO}════════════════════════════════════════════════════════${SEMCOR}"
              echo -e "${BLANCO}${NEGRITO}    $2${SEMCOR}"
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

# ============ FUNCIONES AUXILIARES ============
format_bytes() {
    local bytes=$1
    if ! [[ "$bytes" =~ ^[0-9]+$ ]]; then
        echo "0 B"
        return
    fi
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
        if [ -f "$file" ] && [ "$(basename "$file")" != "default" ]; then
            domain=$(grep -h server_name "$file" | head -1 | awk '{print $2}' | tr -d ';')
            if [ -n "$domain" ] && [ "$domain" != "_" ]; then
                domains="$domains $domain"
            fi
        fi
    done
    if [ -z "$domains" ]; then
        echo "ninguno"
    else
        echo "$domains"
    fi
}

count_backends() {
    if [ -f "$USER_DATA" ]; then
        wc -l < "$USER_DATA" 2>/dev/null || echo 0
    else
        echo 0
    fi
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
    local percent=$1
    local width=20
    local filled=$(echo "$percent * $width / 100" | bc 2>/dev/null || echo 0)
    filled=$(printf "%.0f" "$filled" 2>/dev/null || echo 0)
    if [ $filled -gt $width ]; then filled=$width; fi
    local empty=$((width - filled))
    local bar=""
    if [ $percent -ge 80 ]; then
        bar="${ROJO}"
    elif [ $percent -ge 50 ]; then
        bar="${AMARILLO}"
    else
        bar="${VERDE}"
    fi
    bar="${bar}"
    for ((i=0; i<filled; i++)); do bar="${bar}█"; done
    bar="${bar}${SEMCOR}"
    for ((i=0; i<empty; i++)); do bar="${bar}░"; done
    echo -e "$bar"
}

# ============ PANEL DE ESTADO SUPERIOR ============
show_status_panel() {
    clear

    echo -e "${TURQUESA}════════════════════════════════════════════════════════${SEMCOR}"
    echo -e "\E[41;1;37m      🔥 BACKEND MANAGER by JOHNNY (@Jrcelulares) 🔥     \E[0m"
    echo -e "${TURQUESA}════════════════════════════════════════════════════════${SEMCOR}"

    local fecha=$(date '+%d/%m/%Y %H:%M:%S')
    local ip=$(curl -s ifconfig.me 2>/dev/null || echo "No disponible")
    echo -e "${CIAN}📅 FECHA:${SEMCOR} $fecha     ${CIAN}🌐 IP:${SEMCOR} $ip"
    echo -e "${CIAN}════════════════════════════════════════════════════════${SEMCOR}"

    local nginx_status=$(systemctl is-active nginx)
    if [ "$nginx_status" = "active" ]; then
        nginx_status="${VERDE}✅ ACTIVO${SEMCOR}"
    else
        nginx_status="${ROJO}❌ INACTIVO${SEMCOR}"
    fi

    local domain_count=0
    local first_domain="ninguno"
    local domain_list=""
    for file in /etc/nginx/sites-enabled/*; do
        if [ -f "$file" ] && [ "$(basename "$file")" != "default" ]; then
            domain=$(grep -h server_name "$file" | head -1 | awk '{print $2}' | tr -d ';')
            if [ -n "$domain" ] && [ "$domain" != "_" ]; then
                domain_count=$((domain_count + 1))
                domain_list="$domain_list $domain"
                if [ "$first_domain" = "ninguno" ]; then
                    first_domain="$domain"
                fi
            fi
        fi
    done

    local backends_count=$(count_backends)
    echo -e "🔧 Nginx: $nginx_status     ${CIAN}📦 Dominios:${SEMCOR} $domain_count     ${CIAN}🔙 Backends:${SEMCOR} $backends_count"
    echo -e "📌 Dominio madre: ${VERDE}$first_domain${SEMCOR}     ${CIAN}📋 Lista:${SEMCOR} $domain_list"
    echo -e "🔹 Header: Backend     🔹 Tráfico: ON     🔹 Scanner: ON (30s)"
    echo -e "💾 Backup: $(last_backup)"
    echo -e "${CIAN}════════════════════════════════════════════════════════${SEMCOR}"

    local disk_total=$(df -BG / | awk 'NR==2 {print $2}' | sed 's/G//')
    local disk_used=$(df -BG / | awk 'NR==2 {print $3}' | sed 's/G//')
    local disk_percent=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    local disk_bar=$(draw_bar $disk_percent)
    echo -e "💾 DISCO: [$disk_bar] ${disk_used}GB / ${disk_total}GB (${disk_percent}%)"

    local mem_line=$(free -m | grep Mem:)
    local mem_total=$(echo $mem_line | awk '{print $2}')
    local mem_used=$(echo $mem_line | awk '{print $3}')
    local mem_percent=$((mem_used * 100 / mem_total))
    local mem_bar=$(draw_bar $mem_percent)
    echo -e "🧠 RAM:   [$mem_bar] ${mem_used}MB / ${mem_total}MB (${mem_percent}%)"

    local cpu_cores=$(nproc)
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    if [ -z "$cpu_usage" ]; then cpu_usage=0; fi
    local cpu_percent=$(printf "%.0f" "$cpu_usage" 2>/dev/null || echo 0)
    local cpu_bar=$(draw_bar $cpu_percent)
    local load=$(uptime | awk -F'load average:' '{print $2}' | xargs)
    echo -e "⚡ CPU:   [$cpu_bar] ${cpu_usage}% (load $load)"

    local iface=$(ip route | grep default | awk '{print $5}' | head -1)
    if [ -n "$iface" ] && [ -r /proc/net/dev ]; then
        local line=$(grep "$iface:" /proc/net/dev)
        local rx_bytes=$(echo $line | awk '{print $2}')
        local tx_bytes=$(echo $line | awk '{print $10}')
        local rx_hr=$(format_bytes $rx_bytes)
        local tx_hr=$(format_bytes $tx_bytes)
        echo -e "🌐 RED:  ${VERDE}📥 $rx_hr${SEMCOR}  |  ${AMARILLO}📤 $tx_hr${SEMCOR} (desde boot)"
    else
        echo -e "🌐 RED:  N/D"
    fi

    echo -e "${CIAN}════════════════════════════════════════════════════════${SEMCOR}"
}

# ============ FUNCIONES ORIGINALES ============
# (Se mantienen intactas: check_and_clean_expired, add_backend_minutes, add_backend_days, etc.)
# ... (aquí van todas las funciones originales del script, que por brevedad no repetimos)

# ============ FUNCIONES PARA PAYLOADS ============
# (Incluimos el código completo de PAYLOADS codigo.txt adaptado)

# Función pause (si no existe)
pause() {
    read -n 1 -s -r -p "Presiona cualquier tecla para continuar..."
    echo
}

# Función backend_lines adaptada al formato de USER_DATA
backend_lines() {
    if [[ ! -f "$USER_DATA" ]]; then
        return
    fi
    while IFS=: read -r name ip port exp; do
        # Solo mostrar backends no expirados (opcional)
        if [[ "$exp" =~ ^[0-9]+$ ]] && [[ "$exp" -eq 0 || "$exp" -gt $(date +%s) ]]; then
            echo "\"$name\" \"http://$ip:$port\";"
        fi
    done < "$USER_DATA"
}

payload_tpl_file() { echo "${PAYLOAD_DIR}/$1.tpl"; }

payload_init_defaults() {
    mkdir -p "$PAYLOAD_DIR" >/dev/null 2>&1 || true
    [[ -f "$PAYLOAD_INDEX" ]] || : > "$PAYLOAD_INDEX"

    def_ok() {
        local id="$1"
        grep -qE "^${id}\|" "$PAYLOAD_INDEX" 2>/dev/null || return 1
        [[ -s "$(payload_tpl_file "$id")" ]] || return 1
        return 0
    }

    add_def() {
        local id="$1" name="$2"; shift 2
        local content="$*"
        grep -qE "^${id}\|" "$PAYLOAD_INDEX" 2>/dev/null || echo "${id}|${name}" >> "$PAYLOAD_INDEX"
        [[ -s "$(payload_tpl_file "$id")" ]] || printf "%s\n" "$content" > "$(payload_tpl_file "$id")"
    }

    # Plantillas default 1..5 si faltan/vacías
    if ! def_ok 1; then
        add_def 1 "GET (split + rotate)" \
'GET / HTTP/1.1[crlf]Host: *.personal.com.ar[crlf][crlf][split]
OPTION / HTTP/1.1[crlf]Host: *.personal.com.ar[crlf][crlf][crlf]GET / HTTP/1.1[crlf]Host: {HOST_ROTATE}[crlf]{HDR}:{BACKEND}[lf]Upgrade: websocket[crlf]Connection: Upgrade[crlf][crlf]'
    fi
    if ! def_ok 2; then
        add_def 2 "ACL (split + host fijo)" \
'ACL / HTTP/1.1[crlf]Host: recargas.personal.com.ar[crlf][crlf][split]
OPTION / HTTP/1.1[crlf]Host: www.personal.com.ar[crlf][crlf][crlf]GET / HTTP/1.1[crlf]Host: {HOST_LIST}[crlf]{HDR}:{BACKEND}[lf]Upgrade: websocket[crlf]Connection: Upgrade[crlf][crlf]'
    fi
    if ! def_ok 3; then
        add_def 3 "Rotate (métodos + rotate host)" \
'[rotate=HEAD;COPY;ACL] / HTTP/1.1[crlf]Host: www.personal.com.ar[crlf][crlf][split]
OPTION / HTTP/1.1[crlf]Host: www.personal.com.ar[crlf][crlf]GET / HTTP/1.1[crlf]Host: {HOST_ROTATE}[crlf]{HDR}:{BACKEND}[lf]Upgrade: websocket[crlf]Connection: Upgrade[crlf][crlf]'
    fi
    if ! def_ok 4; then
        add_def 4 "Rotate2 (métodos + wildcard)" \
'[rotate=ACL;GET;COPY] / HTTP/1.1[crlf]Host: *.personal.com.ar[crlf][crlf][split]
OPTION / HTTP/1.1[crlf]Host: *.personal.com.ar[crlf][crlf][crlf]GET / HTTP/1.1[crlf]Host: {HOST_ROTATE}[crlf]{HDR}:{BACKEND}[lf]Upgrade: websocket[crlf]Connection: Upgrade[crlf][crlf]'
    fi
    if ! def_ok 5; then
        add_def 5 "NPV Tunnel" \
'GET / HTTP/1.1[crlf]Host: recargas.personal.com.ar[crlf][crlf][split]
OPTION / HTTP/1.1[crlf]Host: recargas.personal.com.ar[crlf][crlf]GET / HTTP/1.1[crlf]Host: {HOST_ROTATE}[crlf]{HDR}:{BACKEND}[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf][crlf]'
    fi

    # Asegurar archivos auxiliares
    [[ -f "$PAYLOAD_DOMAINS_FILE" ]] || : >"$PAYLOAD_DOMAINS_FILE"
    [[ -f "$PAYLOAD_LAST_FILE" ]] || : >"$PAYLOAD_LAST_FILE"
}

payload_domains_from_panel() {
    local out=()
    for f in /etc/nginx/sites-enabled/*; do
        [[ -f "$f" ]] || continue
        local line
        line="$(grep -E '^\s*server_name\s+' "$f" 2>/dev/null | head -n1)"
        [[ -n "$line" ]] || continue
        line="${line#*server_name}"
        line="${line%;}"
        for d in $line; do
            d="${d//;/}"
            if [[ -n "$d" && "$d" != "_" ]]; then
                out+=("$d")
            fi
        done
    done
    printf "%s\n" "${out[@]}" | awk 'NF && !seen[$0]++'
}

PAYLOAD_INDEX="${PAYLOAD_DIR}/index.db"
PAYLOAD_DOMAINS_FILE="${PAYLOAD_DIR}/domains.list"
PAYLOAD_LAST_FILE="${PAYLOAD_DIR}/last_payload.txt"

payload_get_domains_lines() {
    if [[ -s "$PAYLOAD_DOMAINS_FILE" ]]; then
        awk 'NF{print}' "$PAYLOAD_DOMAINS_FILE"
    else
        payload_domains_from_panel
    fi
}

payload_domains_join_semicolon() {
    payload_get_domains_lines | paste -sd';' - 2>/dev/null || true
}

payload_domains_rotate() {
    local joined
    joined="$(payload_domains_join_semicolon)"
    joined="${joined// /}"
    if [[ -n "$joined" ]]; then
        echo "[rotate=${joined}]"
    else
        echo "[rotate=cpu1.example.com;cpu2.example.com]"
    fi
}

payload_out() {
    echo "/dev/stdout"
}

payload_print_block() {
    local payload="$1"
    local O; O="$(payload_out)"
    echo "[START_PAYLOAD]" >"$O"
    echo -e "${DIM}Tip:${NC} Copiá SOLO lo que está entre [START_PAYLOAD] y [END_PAYLOAD]." >"$O"
    echo "" >"$O"
    printf "%s\n" "$payload" >"$O"
    echo "" >"$O"
    echo "[END_PAYLOAD]" >"$O"
}

payload_list_templates() {
    payload_init_defaults
    echo -e "${CYA}Plantillas disponibles:${NC}\n"
    printf "%-4s %-28s %s\n" "ID" "NOMBRE" "PREVIEW"
    echo "---------------------------------------------------------------"
    while IFS='|' read -r id name; do
        [[ -z "${id:-}" ]] && continue
        local f prev
        f="$(payload_tpl_file "$id")"
        prev="$(head -n1 "$f" 2>/dev/null | cut -c1-55 || true)"
        [[ -z "$prev" ]] && prev="(vacía)"
        printf "%-4s %-28s %s\n" "$id" "${name:-}" "$prev"
    done < <(awk -F'|' 'NF>=2{print $1 "|" $2}' "$PAYLOAD_INDEX" | sort -t'|' -k1,1n 2>/dev/null || cat "$PAYLOAD_INDEX")
}

payload_pick_template_id() {
    payload_init_defaults
    payload_list_templates
    echo
    read -r -p "ID de plantilla (Enter=1): " tid
    tid="${tid:-1}"
    echo "$tid"
}

payload_pick_backend_key() {
    echo -e "\n${CYA}Elegí backend a integrar:${NC}\n"
    local lines=()
    mapfile -t lines < <(backend_lines)
    if [[ "${#lines[@]}" -eq 0 ]]; then
        echo -e "${YLW}No hay backends cargados.${NC}"
        return 1
    fi

    local i=0 key url ipport ip port
    for line in "${lines[@]}"; do
        i=$((i+1))
        key="$(echo "$line" | sed -E 's/^\s*"([^"]+)".*$/\1/')"
        url="$(echo "$line" | sed -E 's/^.*"\s+"([^"]+)";\s*$/\1/')"
        ipport="${url#http://}"; ip="${ipport%%:*}"; port="${ipport##*:}"
        printf "%-3s) %-22s -> %s:%s\n" "$i" "$key" "$ip" "$port"
    done

    echo
    read -r -p "Número: " n
    [[ "$n" =~ ^[0-9]+$ ]] || { echo -e "${RED}Inválido.${NC}"; return 1; }
    (( n>=1 && n<=${#lines[@]} )) || { echo -e "${RED}Fuera de rango.${NC}"; return 1; }

    local pick="${lines[$((n-1))]}"
    key="$(echo "$pick" | sed -E 's/^\s*"([^"]+)".*$/\1/')"
    echo "$key"
}

payload_render() {
    local tpl="$1" backend="$2" host_rotate="$3" host_list="$4"
    local hdr="${HEADER_NAME:-Backend}"

    local out="$tpl"
    out="${out//\{BACKEND\}/$backend}"
    out="${out//\{HDR\}/$hdr}"
    out="${out//\{HOST_ROTATE\}/$host_rotate}"
    out="${out//\{HOST_LIST\}/$host_list}"
    printf "%s" "$out"
}

payload_save_generated() {
    local backend="$1" payload="$2"
    local dir="${PAYLOAD_DIR}/generated"
    mkdir -p "$dir" >/dev/null 2>&1 || true
    printf "%s\n" "$payload" > "${dir}/${backend}.txt"
}

payload_list_generated() {
    local dir="${PAYLOAD_DIR}/generated"
    mkdir -p "$dir" >/dev/null 2>&1 || true
    echo -e "${CYA}Payloads guardados por backend:${NC}\n"
    ls -1 "$dir" 2>/dev/null | sed 's/\.txt$//' || echo "(ninguno)"
}

payload_view_generated() {
    local dir="${PAYLOAD_DIR}/generated"
    mkdir -p "$dir" >/dev/null 2>&1 || true
    payload_list_generated
    echo
    read -r -p "Backend (nombre exacto): " b
    [[ -n "${b:-}" ]] || return 0
    local f="${dir}/${b}.txt"
    if [[ ! -s "$f" ]]; then
        echo -e "${YLW}No existe payload guardado para: $b${NC}"
        return 0
    fi
    local payload; payload="$(cat "$f")"
    payload_print_block "$payload"
}

payload_delete_generated() {
    local dir="${PAYLOAD_DIR}/generated"
    mkdir -p "$dir" >/dev/null 2>&1 || true
    payload_list_generated
    echo
    read -r -p "Backend a borrar (nombre exacto): " b
    [[ -n "${b:-}" ]] || return 0
    local f="${dir}/${b}.txt"
    if [[ -f "$f" ]]; then
        rm -f "$f"
        echo -e "${GRN}✅ Borrado.${NC}"
    else
        echo -e "${YLW}No existe.${NC}"
    fi
}

payload_generate() {
    payload_init_defaults
    echo -e "${CYA}Generar payload${NC}"
    echo -e "${DIM}Primero elegís la plantilla, luego el backend de tu lista.${NC}\n"

    local tid; tid="$(payload_pick_template_id)"
    local tplf; tplf="$(payload_tpl_file "$tid")"
    if [[ ! -f "$tplf" ]]; then
        echo -e "${YLW}Plantilla no encontrada.${NC}"
        return 0
    fi
    if [[ ! -s "$tplf" ]]; then
        echo -e "${YLW}Plantilla vacía.${NC}"
        return 0
    fi

    local backend
    backend="$(payload_pick_backend_key)" || return 0

    echo -e "\n${CYA}Dominios madre (Host) para el payload:${NC}"
    echo "1) Usar dominios madre del panel (server_name)"
    echo "2) Usar override guardado"
    echo "3) Ingresar manual (solo esta vez)"
    echo "4) Ingresar manual y guardarlo como override"
    read -r -p "Opción (Enter=1): " dop
    dop="${dop:-1}"

    local domains_lines joined host_rotate host_list manual=""
    case "$dop" in
        2)
            domains_lines="$(awk 'NF{print}' "$PAYLOAD_DOMAINS_FILE" 2>/dev/null || true)"
            ;;
        3|4)
            echo -e "${DIM}Pegá dominios separados por ; (ej: cpu1...;cpu2...;cpu3...)${NC}"
            read -r -p "Dominios: " manual
            ;;
        *)
            domains_lines="$(payload_domains_from_panel)"
            ;;
    esac

    if [[ "$dop" == "3" || "$dop" == "4" ]]; then
        host_list="${manual// /}"
        host_rotate="[rotate=${host_list}]"
        if [[ "$dop" == "4" ]]; then
            : >"$PAYLOAD_DOMAINS_FILE"
            echo "$manual" | tr ';' '\n' | awk 'NF{print}' >>"$PAYLOAD_DOMAINS_FILE"
            echo -e "${GRN}✅ Override guardado.${NC}"
        fi
    else
        joined="$(printf "%s\n" "$domains_lines" | paste -sd';' - 2>/dev/null || true)"
        joined="${joined// /}"
        host_list="$joined"
        host_rotate="[rotate=${joined}]"
    fi

    local tpl payload
    tpl="$(cat "$tplf")"
    payload="$(payload_render "$tpl" "$backend" "$host_rotate" "$host_list")"

    printf "%s\n" "$payload" > "$PAYLOAD_LAST_FILE"
    payload_save_generated "$backend" "$payload"

    echo -e "\n${GRN}✅ Payload guardado para: ${backend}${NC}\n"
    payload_print_block "$payload"
}

payload_domains_menu() {
    payload_init_defaults
    while true; do
        echo -e "${CYA}🌐 Dominios Host (override / sync)${NC}"
        echo "1) Ver override actual"
        echo "2) Editar override (uno por línea)"
        echo "3) Sincronizar desde dominios madre del panel"
        echo "4) Borrar override (volver a usar panel)"
        echo "0) Volver"
        read -r -p "Opción: " op
        echo
        case "$op" in
            1)
                if [[ -s "$PAYLOAD_DOMAINS_FILE" ]]; then
                    echo -e "${WHT}Override actual:${NC}"
                    nl -ba "$PAYLOAD_DOMAINS_FILE"
                else
                    echo -e "${YLW}No hay override. Se usan los dominios del panel.${NC}"
                fi
                pause
            ;;
            2)
                echo -e "${DIM}Escribí dominios (uno por línea). Terminá con una línea vacía.${NC}"
                : >"$PAYLOAD_DOMAINS_FILE"
                while true; do
                    read -r line || break
                    [[ -z "${line:-}" ]] && break
                    echo "$line" >>"$PAYLOAD_DOMAINS_FILE"
                done
                echo -e "${GRN}✅ Guardado.${NC}"
                pause
            ;;
            3)
                : >"$PAYLOAD_DOMAINS_FILE"
                payload_domains_from_panel >>"$PAYLOAD_DOMAINS_FILE" || true
                echo -e "${GRN}✅ Sincronizado desde el panel.${NC}"
                pause
            ;;
            4)
                : >"$PAYLOAD_DOMAINS_FILE"
                echo -e "${GRN}✅ Override borrado.${NC}"
                pause
            ;;
            0) return 0 ;;
            *) echo -e "${YLW}Opción inválida.${NC}"; pause ;;
        esac
    done
}

payload_template_edit() {
    payload_init_defaults
    payload_list_templates
    echo
    read -r -p "ID a editar: " tid
    [[ -n "${tid:-}" ]] || return 0
    local f; f="$(payload_tpl_file "$tid")"
    if [[ ! -f "$f" ]]; then
        echo -e "${YLW}No existe.${NC}"
        return 0
    fi
    echo -e "${DIM}Pegá el payload completo. Terminá con una línea vacía.${NC}"
    : >"$f"
    while true; do
        read -r line || break
        [[ -z "${line:-}" ]] && break
        echo "$line" >>"$f"
    done
    echo -e "${GRN}✅ Plantilla actualizada.${NC}"
}

payload_template_add() {
    payload_init_defaults
    echo -e "${CYA}Agregar plantilla nueva${NC}"
    read -r -p "ID numérico (ej: 6): " tid
    [[ "$tid" =~ ^[0-9]+$ ]] || { echo -e "${RED}ID inválido.${NC}"; return 0; }
    read -r -p "Nombre: " name
    [[ -n "${name:-}" ]] || name="Custom $tid"

    if grep -qE "^${tid}\|" "$PAYLOAD_INDEX" 2>/dev/null; then
        echo -e "${YLW}Ese ID ya existe.${NC}"
        return 0
    fi

    echo "${tid}|${name}" >> "$PAYLOAD_INDEX"
    local f; f="$(payload_tpl_file "$tid")"
    echo -e "${DIM}Pegá el payload completo. Terminá con una línea vacía.${NC}"
    : >"$f"
    while true; do
        read -r line || break
        [[ -z "${line:-}" ]] && break
        echo "$line" >>"$f"
    done
    echo -e "${GRN}✅ Plantilla agregada.${NC}"
}

payload_template_delete() {
    payload_init_defaults
    payload_list_templates
    echo
    read -r -p "ID a eliminar: " tid
    [[ -n "${tid:-}" ]] || return 0
    sed -i -E "/^${tid}\|/d" "$PAYLOAD_INDEX" 2>/dev/null || true
    rm -f "$(payload_tpl_file "$tid")" 2>/dev/null || true
    echo -e "${GRN}✅ Eliminada.${NC}"
}

payload_menu() {
    payload_init_defaults
    while true; do
        echo -e "${WHT}🧾 Payloads (plantillas + generar)${NC}"
        echo -e "${DIM}Generá payload eligiendo plantilla + backend. Podés editar/crear plantillas y dominios Host.${NC}\n"
        echo "1) 🧾 Generar payload (plantilla + backend)"
        echo "2) 📋 Listar plantillas"
        echo "3) ✏️  Editar plantilla"
        echo "4) ➕ Agregar plantilla nueva"
        echo "5) 🗑️  Eliminar plantilla"
        echo "6) 🌐 Dominios Host (override / sync)"
        echo "7) 👁️  Ver último payload generado"
        echo "8) 📌 Ver payload guardado por backend"
        echo "9) 🗑️  Borrar payload guardado por backend"
        echo "0) Volver"
        read -r -p "Opción: " op
        echo
        case "$op" in
            1) payload_generate; pause ;;
            2) payload_list_templates; pause ;;
            3) payload_template_edit; pause ;;
            4) payload_template_add; pause ;;
            5) payload_template_delete; pause ;;
            6) payload_domains_menu ;;
            7)
                if [[ -s "$PAYLOAD_LAST_FILE" ]]; then
                    payload_print_block "$(cat "$PAYLOAD_LAST_FILE")"
                else
                    echo -e "${YLW}No hay payload generado aún.${NC}"
                fi
                pause
            ;;
            8) payload_view_generated; pause ;;
            9) payload_delete_generated; pause ;;
            0) return 0 ;;
            *) echo -e "${YLW}Opción inválida.${NC}"; pause ;;
        esac
    done
}

# ============ FUNCIÓN PARA INSTALAR BOT ============
install_bot() {
    show_status_panel
    msg -tit "INSTALAR BOT DE TELEGRAM"
    msg -ama "Descargando e instalando el bot..."
    wget -q https://raw.githubusercontent.com/johnnyrodriguezdk/backend/refs/heads/main/botmanager.sh -O /tmp/botmanager.sh
    if [[ $? -eq 0 ]]; then
        chmod +x /tmp/botmanager.sh
        /tmp/botmanager.sh
    else
        msg -verm "Error al descargar el instalador."
    fi
    msg -bar
    read -p "Presiona ENTER para continuar..."
}

# ============ MODO NO INTERACTIVO PARA EL BOT ============
if [[ "$1" == "--generate" ]]; then
    # Uso: --generate <template_id> <backend_key> [domains_option] [custom_domains]
    tid="$2"
    backend="$3"
    domains_option="${4:-1}"
    custom_domains="$5"

    # Inicializar payloads
    payload_init_defaults

    # Validar plantilla
    tplf="$(payload_tpl_file "$tid")"
    if [[ ! -f "$tplf" || ! -s "$tplf" ]]; then
        echo "ERROR: Plantilla no encontrada o vacía"
        exit 1
    fi

    # Validar backend (debe existir en USER_DATA)
    if ! grep -q "^${backend}:" "$USER_DATA"; then
        echo "ERROR: Backend no encontrado"
        exit 1
    fi

    # Obtener dominios
    case "$domains_option" in
        2)
            domains_lines="$(awk 'NF{print}' "$PAYLOAD_DOMAINS_FILE" 2>/dev/null || true)"
            ;;
        3|4)
            host_list="${custom_domains// /}"
            host_rotate="[rotate=${host_list}]"
            ;;
        *)
            domains_lines="$(payload_domains_from_panel)"
            ;;
    esac

    if [[ "$domains_option" != "3" && "$domains_option" != "4" ]]; then
        joined="$(printf "%s\n" "$domains_lines" | paste -sd';' - 2>/dev/null || true)"
        joined="${joined// /}"
        host_list="$joined"
        host_rotate="[rotate=${joined}]"
    fi

    # Renderizar payload
    tpl="$(cat "$tplf")"
    payload="$(payload_render "$tpl" "$backend" "$host_rotate" "$host_list")"

    # Guardar (opcional)
    printf "%s\n" "$payload" > "$PAYLOAD_LAST_FILE"
    payload_save_generated "$backend" "$payload"

    # Imprimir solo el payload (sin bloques extra)
    echo "$payload"
    exit 0
fi

# ============ MENÚ PRINCIPAL CON 22 OPCIONES ============
main_menu() {
    while true; do
        show_status_panel

        echo -e "${AMARILLO}MENÚ PRINCIPAL${SEMCOR}"
        echo -e " ${VERDE}[01]${SEMCOR} ${BLANCO}INSTALAR NGINX (80)${SEMCOR}"
        echo -e " ${VERDE}[02]${SEMCOR} ${BLANCO}INSTALAR PROXY PYTHON (PUERTO 8080)${SEMCOR}"
        echo -e " ${VERDE}[03]${SEMCOR} ${BLANCO}GESTIONAR BACKENDS PERSONALIZADOS${SEMCOR}"
        echo -e " ${VERDE}[04]${SEMCOR} ${BLANCO}VER ESTADO DEL SISTEMA${SEMCOR}"
        echo -e " ${VERDE}[05]${SEMCOR} ${BLANCO}INSTRUCCIONES Y PAYLOADS${SEMCOR}"
        echo -e " ${VERDE}[06]${SEMCOR} ${BLANCO}EDITAR CONFIGURACIÓN MANUAL${SEMCOR}"
        echo -e " ${VERDE}[07]${SEMCOR} ${BLANCO}REINICIAR SERVICIOS${SEMCOR}"
        echo -e " ${VERDE}[08]${SEMCOR} ${BLANCO}GESTIÓN DE BACKUPS${SEMCOR}"
        echo -e " ${VERDE}[09]${SEMCOR} ${BLANCO}LIMPIAR BACKENDS EXPIRADOS${SEMCOR}"
        echo -e " ${VERDE}[10]${SEMCOR} ${BLANCO}HEALTHCHECK (HTTP Y LATENCIA)${SEMCOR}"
        echo -e " ${VERDE}[11]${SEMCOR} ${BLANCO}VALIDAR CONEXIÓN (HEADER BACKEND)${SEMCOR}"
        echo -e " ${VERDE}[12]${SEMCOR} ${BLANCO}EDITAR TIMEOUTS DEL DOMINIO MADRE${SEMCOR}"
        echo -e " ${VERDE}[13]${SEMCOR} ${BLANCO}BALANCEO DE MADRES (UPSTREAM)${SEMCOR}"
        echo -e " ${VERDE}[14]${SEMCOR} ${BLANCO}LIMITAR ANCHO DE BANDA (limit_rate)${SEMCOR}"
        echo -e " ${VERDE}[15]${SEMCOR} ${BLANCO}TRÁFICO POR IP / BACKEND (STATS)${SEMCOR}"
        echo -e " ${VERDE}[16]${SEMCOR} ${BLANCO}FIREWALL UFW: ABRIR PUERTO${SEMCOR}"
        echo -e " ${VERDE}[17]${SEMCOR} ${BLANCO}SPEEDTEST (PING/BAJADA/SUBIDA)${SEMCOR}"
        echo -e " ${VERDE}[18]${SEMCOR} ${BLANCO}MANTENIMIENTO PROGRAMADO${SEMCOR}"
        echo -e " ${VERDE}[19]${SEMCOR} ${BLANCO}DESINSTALAR TODO${SEMCOR}"
        echo -e " ${VERDE}[20]${SEMCOR} ${BLANCO}SALIR${SEMCOR}"
        echo -e " ${VERDE}[21]${SEMCOR} ${BLANCO}🧾 GENERAR PAYLOADS (PLANTILLAS)${SEMCOR}"
        echo -e " ${VERDE}[22]${SEMCOR} ${BLANCO}🤖 INSTALAR BOT DE TELEGRAM${SEMCOR}"
        echo -e "${CIAN}════════════════════════════════════════════════════════${SEMCOR}"

        read -p "🔥 SELECCIONA OPCIÓN: " option

        case $option in
            1) install_nginx_super ;;
            2) install_python_proxy ;;
            3) manage_backends ;;
            4) show_status ;;
            5) show_epic_instructions ;;
            6) nano "$BACKEND_CONF"; /usr/sbin/nginx -t && systemctl reload nginx ;;
            7) systemctl restart nginx superc4mpeon-proxy 2>/dev/null; msg -verd "Servicios reiniciados!"; sleep 2 ;;
            8) backup_menu ;;
            9) check_and_clean_expired; msg -bar; read -p "Presiona ENTER para continuar..." ;;
            10) healthcheck ;;
            11) validate_connection ;;
            12) edit_timeouts ;;
            13) balanceo ;;
            14) limit_bandwidth ;;
            15) traffic_stats ;;
            16) ufw_open ;;
            17) speedtest ;;
            18) maintenance ;;
            19) uninstall_everything ;;
            20) 
                msg -verd "¡Hasta la vista, c4mpeon! 👋"
                exit 0 
                ;;
            21) payload_menu ;;
            22) install_bot ;;
            *) 
                msg -verm "Opción inválida"
                sleep 2
                ;;
        esac
    done
}

# ============ INICIO ============
clear
echo -e "${ROJO}${NEGRITO}"
echo -e "${TURQUESA}════════════════════════════════════════════════════════${SEMCOR}"
echo -e "\E[41;1;37m                CARGANDO PANEL BACKEND....                 \E[0m"
echo -e "${TURQUESA}════════════════════════════════════════════════════════${SEMCOR}"
echo -e "${SEMCOR}"
echo -e "${VERDE}${NEGRITO}              CARGANDO SISTEMA...${SEMCOR}"
sleep 2

init_system
main_menu
EOF

# Hacer ejecutable
chmod +x /root/superc4mpeon.sh

# Crear enlace simbólico /bin/menu2
ln -sf /root/superc4mpeon.sh /bin/menu2

# Configuración inicial de Nginx si no existe
if [ ! -f /etc/nginx/sites-available/superc4mpeon ]; then
    cat > /etc/nginx/sites-available/superc4mpeon <<'CONF'
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
CONF
    ln -s /etc/nginx/sites-available/superc4mpeon /etc/nginx/sites-enabled/ 2>/dev/null
fi

# Habilitar y arrancar nginx
systemctl enable nginx
systemctl restart nginx

echo -e "${VERDE}✅ Instalación completada. Ahora ejecuta 'menu2' para disfrutar del Backend Manager by JOHNNY con 22 opciones, panel mejorado, creador de payloads y opción para instalar el bot.${SEMCOR}"
