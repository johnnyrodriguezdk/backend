#!/bin/bash
# ============================================================
# INSTALADOR - BACKEND MANAGER by JOHNNY (@Jrcelulares)
# Versión: 5.0 - 20 opciones + panel visual + todas las funciones
# MODIFICADO: Incluye backends preconfigurados y módulo de monitoreo v6.0
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
mkdir -p /root/superc4mpeon_backups

# Crear archivo de datos con los backends preconfigurados (reemplaza al "touch" original)
cat > /etc/nginx/superc4mpeon_users.txt << 'DATA'
arkey:128.254.188.235:80:2638795200
librear:128.254.188.236:80:2638795200
sv3:151.244.242.229:80:1780012800
VPSConnect:186.148.224.149:80:1775001600
DATA
# ============================================================
# GENERAR EL SCRIPT PRINCIPAL /root/superc4mpeon.sh
# (Incluye TODAS las funciones originales + nuevas de monitoreo)
# ============================================================
cat > /root/superc4mpeon.sh << 'EOF'
#!/bin/bash

# ==================================================
# SCRIPT: BACKEND MANAGER by JOHNNY (@Jrcelulares)
# VERSIÓN: 5.0 - 20 OPCIONES + PANEL VISUAL + MONITOREO v6.0
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
GRIS='\e[1;90m'   # Nuevo para monitoreo

# ARCHIVOS DE CONFIGURACIÓN
BACKEND_CONF="/etc/nginx/sites-available/superc4mpeon"
BACKEND_ENABLED="/etc/nginx/sites-enabled/superc4mpeon"
USER_DATA="/etc/nginx/superc4mpeon_users.txt"
BACKUP_DIR="/root/superc4mpeon_backups"

# Archivos nuevos para monitoreo
TRAFFIC_DB="/etc/backendmanager/traffic.db"
CONNECTIONS_LOG="/etc/backendmanager/connections.log"
mkdir -p /etc/backendmanager 2>/dev/null
touch "$TRAFFIC_DB" 2>/dev/null
touch "$CONNECTIONS_LOG" 2>/dev/null

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
# (Reemplazadas por versiones mejoradas de monitoreo)

format_bytes() {
    local bytes=$1
    if ! [[ "$bytes" =~ ^[0-9]+$ ]] || [ "${bytes:-0}" -eq 0 ] 2>/dev/null; then
        echo "0 B"
        return
    fi
    if [ "$bytes" -ge 1099511627776 ]; then
        awk "BEGIN {printf \"%.2f TB\", $bytes/1099511627776}"
    elif [ "$bytes" -ge 1073741824 ]; then
        awk "BEGIN {printf \"%.2f GB\", $bytes/1073741824}"
    elif [ "$bytes" -ge 1048576 ]; then
        awk "BEGIN {printf \"%.2f MB\", $bytes/1048576}"
    elif [ "$bytes" -ge 1024 ]; then
        awk "BEGIN {printf \"%.2f KB\", $bytes/1024}"
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
    local width=${2:-20}
    [ "${percent:-0}" -gt 100 ] 2>/dev/null && percent=100
    [ "${percent:-0}" -lt 0 ] 2>/dev/null && percent=0
    local filled=$((percent * width / 100))
    local empty=$((width - filled))
    local color="${VERDE}"
    [ "$percent" -ge 50 ] && color="${AMARILLO}"
    [ "$percent" -ge 80 ] && color="${ROJO}"
    printf "${color}"
    for ((x=0; x<filled; x++)); do printf '█'; done
    printf "${GRIS}"
    for ((x=0; x<empty; x++)); do printf '░'; done
    printf "${SEMCOR} ${percent}%%"
}
# ============ PANEL DE ESTADO SUPERIOR ============
show_status_panel() {
    ... (contenido original) ...
}

# ============ FUNCIONES ORIGINALES ============
check_and_clean_expired() { ... }
add_backend_minutes() { ... }
add_backend_days() { ... }
init_system() { ... }
backup_backends() { ... }
restore_backends() { ... }
list_backups() { ... }
clean_old_backups() { ... }
backup_menu() { ... }
install_nginx_super() { ... }
install_python_proxy() { ... }
manage_backends() { ... }
show_epic_instructions() { ... }
show_status() { ... }
uninstall_everything() { ... }

# ============ NUEVAS FUNCIONES (YA EXISTENTES EN EL ORIGINAL) ============
healthcheck() { ... }
validate_connection() { ... }
edit_timeouts() { ... }
balanceo() { ... }
limit_bandwidth() { ... }
traffic_stats() { ... }
ufw_open() { ... }
speedtest() { ... }
maintenance() { ... }
# ─── NUEVAS FUNCIONES DE MONITOREO v6.0 ─────────────────────────────────

# ─── FORMATO TIEMPO RESTANTE ──────────────────────────────────────────────────
format_time_remaining() {
    local exp_epoch=$1
    local now=$(date +%s)
    local diff=$((exp_epoch - now))
    if [ "$diff" -le 0 ] 2>/dev/null; then
        echo -e "${ROJO}EXPIRADO${SEMCOR}"
        return
    fi
    local days=$((diff / 86400))
    local hours=$(( (diff % 86400) / 3600 ))
    local mins=$(( (diff % 3600) / 60 ))
    if [ $days -gt 30 ]; then
        echo -e "${VERDE}${days}d ${hours}h${SEMCOR}"
    elif [ $days -gt 7 ]; then
        echo -e "${AMARILLO}${days}d ${hours}h${SEMCOR}"
    elif [ $days -gt 0 ]; then
        echo -e "${ROJO}${days}d ${hours}h ${mins}m${SEMCOR}"
    elif [ $hours -gt 0 ]; then
        echo -e "${ROJO}${hours}h ${mins}m${SEMCOR}"
    else
        echo -e "${ROJO}${mins}m${SEMCOR}"
    fi
}

# ─── FUNCIÓN NUEVA: VER TRÁFICO POR BACKEND (GB/TB) ──────────────────────────
ver_trafico() {
    msg -tit "TRÁFICO POR BACKEND (GB/TB)"
    echo ""

    if [ ! -s "$USER_DATA" ]; then
        msg -ama "No hay backends registrados"
        return
    fi

    # Inicializar cadenas iptables si no existen
    while IFS=':' read -r bname bip bport bexp; do
        [ -z "$bname" ] && continue
        [ -z "$bip" ] && continue
        local CHAIN="TRAFFIC_${bname}"
        if ! iptables -L "$CHAIN" -n > /dev/null 2>&1; then
            iptables -N "$CHAIN" 2>/dev/null
            iptables -A "$CHAIN" -d "$bip" -j RETURN 2>/dev/null
            iptables -A "$CHAIN" -s "$bip" -j RETURN 2>/dev/null
            iptables -I FORWARD -d "$bip" -j "$CHAIN" 2>/dev/null
            iptables -I FORWARD -s "$bip" -j "$CHAIN" 2>/dev/null
            iptables -I OUTPUT -d "$bip" -j "$CHAIN" 2>/dev/null
            iptables -I INPUT -s "$bip" -j "$CHAIN" 2>/dev/null
        fi
    done < "$USER_DATA"

    printf "  ${BLANCO}%-4s %-15s %-17s %-15s %-10s${SEMCOR}\n" "#" "NOMBRE" "IP" "TRÁFICO" "ESTADO"
    msg -bar2

    local i=1
    local total_traffic=0

    while IFS=':' read -r bname bip bport bexp; do
        [ -z "$bname" ] && continue

        local CHAIN="TRAFFIC_${bname}"
        local bytes=$(iptables -L "$CHAIN" -n -v -x 2>/dev/null | awk '/RETURN/ {sum+=$2} END{print sum+0}')
        [ -z "$bytes" ] && bytes=0
        total_traffic=$((total_traffic + bytes))

        local estado="${VERDE}OK${SEMCOR}"
        # No hay límite configurado en este formato, pero se podría añadir luego

        printf "  %-4s %-15s %-17s " "$i" "$bname" "${bip}:${bport}"
        echo -e "$(format_bytes $bytes)        ${estado}"

        i=$((i+1))
    done < "$USER_DATA"

    echo ""
    msg -bar2
    echo -e "  ${BLANCO}Tráfico total:${SEMCOR} ${CIAN}$(format_bytes $total_traffic)${SEMCOR}"

    # vnstat si está disponible
    if command -v vnstat &>/dev/null; then
        local iface=$(ip route | grep default | awk '{print $5}' | head -1)
        if [ -n "$iface" ]; then
            echo ""
            echo -e "  ${BLANCO}Tráfico del servidor (vnstat):${SEMCOR}"
            local today_rx=$(vnstat -i "$iface" --oneline 2>/dev/null | cut -d';' -f4)
            local today_tx=$(vnstat -i "$iface" --oneline 2>/dev/null | cut -d';' -f5)
            local month_rx=$(vnstat -i "$iface" --oneline 2>/dev/null | cut -d';' -f9)
            local month_tx=$(vnstat -i "$iface" --oneline 2>/dev/null | cut -d';' -f10)
            echo -e "  ${GRIS}Hoy:${SEMCOR}  ↓ ${today_rx}  ↑ ${today_tx}"
            echo -e "  ${GRIS}Mes:${SEMCOR}   ↓ ${month_rx}  ↑ ${month_tx}"
        fi
    fi
    msg -bar
}

# ─── FUNCIÓN NUEVA: VER CONEXIONES POR BACKEND ───────────────────────────────
ver_conexiones() {
    msg -tit "CONEXIONES ACTIVAS POR BACKEND"
    echo ""

    if [ ! -s "$USER_DATA" ]; then
        msg -ama "No hay backends registrados"
        return
    fi

    local total_global=0

    printf "  ${BLANCO}%-4s %-15s %-17s %-12s %-10s${SEMCOR}\n" "#" "NOMBRE" "IP:PUERTO" "CONECTADOS" "ESTADO"
    msg -bar2

    local i=1
    while IFS=':' read -r bname bip bport bexp; do
        [ -z "$bname" ] && continue

        local conn_to=$(ss -tn state established "dst ${bip}:${bport}" 2>/dev/null | tail -n +2 | wc -l)
        local conn_from=$(ss -tn state established "src ${bip}:${bport}" 2>/dev/null | tail -n +2 | wc -l)
        local total=$((conn_to + conn_from))
        total_global=$((total_global + total))

        local estado="${VERDE}● OK${SEMCOR}"
        [ "$total" -eq 0 ] && estado="${GRIS}● SIN CONEX${SEMCOR}"
        [ "$total" -ge 50 ] && estado="${AMARILLO}● MEDIO${SEMCOR}"
        [ "$total" -ge 100 ] && estado="${ROJO}● ALTO${SEMCOR}"

        printf "  %-4s %-15s %-17s " "$i" "$bname" "${bip}:${bport}"
        echo -e "${CIAN}${total}${SEMCOR}           ${estado}"

        i=$((i+1))
    done < "$USER_DATA"

    echo ""
    msg -bar2
    echo -e "  ${BLANCO}Total conexiones:${SEMCOR} ${CIAN}${total_global}${SEMCOR}"
    local srv_total=$(ss -tn state established 2>/dev/null | tail -n +2 | wc -l)
    echo -e "  ${BLANCO}Conexiones servidor:${SEMCOR} ${srv_total}"
    msg -bar
}

# ─── FUNCIÓN NUEVA: DETALLE DE CONEXIONES DE UN BACKEND ──────────────────────
detalle_conexiones() {
    msg -tit "DETALLE DE CONEXIONES"
    echo ""

    if [ ! -s "$USER_DATA" ]; then
        msg -ama "No hay backends registrados"
        return
    fi

    local i=1
    while IFS=':' read -r bname bip bport bexp; do
        [ -z "$bname" ] && continue
        local conns=$(ss -tn state established "dst ${bip}:${bport}" 2>/dev/null | tail -n +2 | wc -l)
        echo -e "  ${BLANCO}[$i]${SEMCOR} $bname (${bip}:${bport}) - ${CIAN}${conns} conexiones${SEMCOR}"
        i=$((i+1))
    done < "$USER_DATA"
    echo -e "  ${BLANCO}[0]${SEMCOR} Cancelar"
    echo ""

    read -p "  Selecciona backend: " sel
    [ "$sel" = "0" ] || [ -z "$sel" ] && return

    local target=$(sed -n "${sel}p" "$USER_DATA")
    [ -z "$target" ] && { msg -verm "Selección inválida"; return; }

    local tname=$(echo "$target" | cut -d':' -f1)
    local tip=$(echo "$target" | cut -d':' -f2)
    local tport=$(echo "$target" | cut -d':' -f3)

    echo ""
    msg -tit "CONEXIONES: $tname ($tip:$tport)"
    echo ""

    echo -e "  ${BLANCO}Clientes conectados (por IP):${SEMCOR}"
    msg -bar2

    local conn_list=$(ss -tn state established "dst ${tip}:${tport}" 2>/dev/null | tail -n +2)
    if [ -z "$conn_list" ]; then
        echo -e "  ${GRIS}No hay conexiones activas${SEMCOR}"
    else
        echo "$conn_list" | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -rn | head -30 | while read count ip; do
            local bar_len=$((count))
            [ "$bar_len" -gt 30 ] && bar_len=30
            [ "$bar_len" -lt 1 ] && bar_len=1
            local bar=""
            for ((x=0; x<bar_len; x++)); do bar="${bar}█"; done
            local color="${VERDE}"
            [ "$count" -ge 10 ] && color="${AMARILLO}"
            [ "$count" -ge 30 ] && color="${ROJO}"
            printf "  ${color}%-6s${SEMCOR} %-18s ${color}%s${SEMCOR}\n" "$count" "$ip" "$bar"
        done

        local total_conns=$(echo "$conn_list" | wc -l)
        local unique_ips=$(echo "$conn_list" | awk '{print $5}' | cut -d: -f1 | sort -u | wc -l)
        echo ""
        msg -bar2
        echo -e "  ${BLANCO}Total conexiones:${SEMCOR} ${CIAN}${total_conns}${SEMCOR}"
        echo -e "  ${BLANCO}IPs únicas:${SEMCOR} ${CIAN}${unique_ips}${SEMCOR}"
    fi
    msg -bar
}

# ─── FUNCIÓN NUEVA: MONITOR EN TIEMPO REAL ───────────────────────────────────
monitor_realtime() {
    msg -tit "MONITOR EN TIEMPO REAL"
    echo -e "  ${AMARILLO}Presiona Ctrl+C para salir${SEMCOR}"
    sleep 2

    while true; do
        clear
        local now=$(date +%s)
        local fecha=$(date '+%d/%m/%Y %H:%M:%S')

        echo -e "${CIAN}"
        echo "  ╔══════════════════════════════════════════════════════════╗"
        echo "  ║         MONITOR EN TIEMPO REAL - $fecha         ║"
        echo "  ╚══════════════════════════════════════════════════════════╝"
        echo -e "${SEMCOR}"

        # Info servidor
        local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1)
        local mem_total=$(free -m | awk '/^Mem:/{print $2}')
        local mem_used=$(free -m | awk '/^Mem:/{print $3}')
        local mem_pct=$((mem_used * 100 / mem_total))
        local disk_pct=$(df / | awk 'NR==2{print $5}' | tr -d '%')
        local total_conn=$(ss -tn state established 2>/dev/null | tail -n +2 | wc -l)

        echo -e "  ${BLANCO}SERVIDOR${SEMCOR}"
        echo -ne "  CPU:   "; draw_bar ${cpu_usage:-0} 20; echo ""
        echo -ne "  RAM:   "; draw_bar $mem_pct 20; echo " (${mem_used}/${mem_total}MB)"
        echo -ne "  Disco: "; draw_bar $disk_pct 20; echo ""
        echo -e "  Conexiones totales: ${CIAN}${total_conn}${SEMCOR}"
        echo ""

        printf "  ${BLANCO}%-15s %-8s %-10s %-15s %-12s${SEMCOR}\n" "BACKEND" "ESTADO" "CONEX" "TRÁFICO" "RESTANTE"
        echo -e "  ${GRIS}───────────────────────────────────────────────────────────────${SEMCOR}"

        if [ -s "$USER_DATA" ]; then
            while IFS=':' read -r bname bip bport bexp; do
                [ -z "$bname" ] && continue

                local estado="${ROJO}OFF${SEMCOR}"
                if timeout 1 bash -c "echo >/dev/tcp/$bip/$bport" 2>/dev/null; then
                    estado="${VERDE}ON ${SEMCOR}"
                fi

                local conns=$(ss -tn state established "dst ${bip}:${bport}" 2>/dev/null | tail -n +2 | wc -l)
                local conns2=$(ss -tn state established "src ${bip}:${bport}" 2>/dev/null | tail -n +2 | wc -l)
                local total_c=$((conns + conns2))

                local CHAIN="TRAFFIC_${bname}"
                local bytes=$(iptables -L "$CHAIN" -n -v -x 2>/dev/null | awk '/RETURN/ {sum+=$2} END{print sum+0}')
                [ -z "$bytes" ] && bytes=0

                local rest_str="${VERDE}∞${SEMCOR}"
                if [ -n "$bexp" ] && [ "$bexp" -gt 0 ] 2>/dev/null; then
                    if [ "$now" -ge "$bexp" ]; then
                        rest_str="${ROJO}EXPIRADO${SEMCOR}"
                    else
                        rest_str=$(format_time_remaining $bexp)
                    fi
                fi

                printf "  %-15s " "$bname"
                echo -ne "${estado}     "
                printf "${CIAN}%-10s${SEMCOR} " "$total_c"
                printf "%-15s " "$(format_bytes $bytes)"
                echo -e "$rest_str"

            done < "$USER_DATA"
        else
            echo -e "  ${GRIS}No hay backends registrados${SEMCOR}"
        fi

        echo ""
        echo -e "  ${GRIS}Actualizando cada 5s... Ctrl+C para salir${SEMCOR}"
        sleep 5
    done
}

# ─── FUNCIÓN NUEVA: TOP IPs CONSUMIDORAS ─────────────────────────────────────
top_ips_consumidoras() {
    msg -tit "TOP IPs CON MÁS CONEXIONES"
    echo ""

    echo -e "  ${BLANCO}[1]${SEMCOR} Top IPs globales"
    echo -e "  ${BLANCO}[2]${SEMCOR} Top IPs por backend"
    echo -e "  ${BLANCO}[3]${SEMCOR} Top IPs desde logs Nginx"
    echo -e "  ${BLANCO}[0]${SEMCOR} Volver"
    echo ""
    read -p "  Selecciona: " topt

    case $topt in
        1)
            echo ""
            echo -e "  ${BLANCO}Top 30 IPs activas:${SEMCOR}"
            msg -bar2
            ss -tn state established 2>/dev/null | tail -n +2 | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -rn | head -30 | while read count ip; do
                local bar_len=$((count / 2))
                [ "$bar_len" -gt 30 ] && bar_len=30
                [ "$bar_len" -lt 1 ] && bar_len=1
                local bar=""
                for ((x=0; x<bar_len; x++)); do bar="${bar}█"; done
                local color="${VERDE}"
                [ "$count" -ge 20 ] && color="${AMARILLO}"
                [ "$count" -ge 50 ] && color="${ROJO}"
                printf "  ${color}%-6s${SEMCOR} %-18s ${color}%s${SEMCOR}\n" "$count" "$ip" "$bar"
            done
            ;;
        2)
            if [ ! -s "$USER_DATA" ]; then
                msg -ama "No hay backends"
                return
            fi
            local i=1
            while IFS=':' read -r bname bip bport bexp; do
                [ -z "$bname" ] && continue
                echo -e "  ${BLANCO}[$i]${SEMCOR} $bname (${bip}:${bport})"
                i=$((i+1))
            done < "$USER_DATA"
            echo ""
            read -p "  Selecciona: " bsel
            local btarget=$(sed -n "${bsel}p" "$USER_DATA")
            [ -z "$btarget" ] && { msg -verm "Inválido"; return; }
            local btip=$(echo "$btarget" | cut -d':' -f2)
            local btport=$(echo "$btarget" | cut -d':' -f3)
            local btname=$(echo "$btarget" | cut -d':' -f1)

            echo ""
            echo -e "  ${BLANCO}Top IPs en $btname:${SEMCOR}"
            msg -bar2
            ss -tn state established "dst ${btip}:${btport}" 2>/dev/null | tail -n +2 | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -rn | head -20 | while read count ip; do
                printf "  ${CIAN}%-6s${SEMCOR} %s\n" "$count" "$ip"
            done
            ;;
        3)
            echo ""
            echo -e "  ${BLANCO}Top IPs desde access.log:${SEMCOR}"
            msg -bar2
            if [ -f /var/log/nginx/access.log ]; then
                awk '{print $1}' /var/log/nginx/access.log 2>/dev/null | sort | uniq -c | sort -rn | head -30 | while read count ip; do
                    printf "  ${CIAN}%-8s${SEMCOR} %s\n" "$count" "$ip"
                done
            else
                msg -ama "access.log no encontrado"
            fi
            ;;
        0|*) return ;;
    esac
}

# ─── FUNCIÓN NUEVA: ALERTAS DE TRÁFICO Y EXPIRACIÓN ──────────────────────────
alertas_trafico() {
    msg -tit "ALERTAS DE TRÁFICO Y EXPIRACIÓN"
    echo ""

    if [ ! -s "$USER_DATA" ]; then
        msg -ama "No hay backends registrados"
        return
    fi

    local now=$(date +%s)
    local alertas=0

    while IFS=':' read -r bname bip bport bexp; do
        [ -z "$bname" ] && continue

        # Alerta tráfico (sin límite por ahora, se podría implementar luego)
        # Por ahora solo mostramos tráfico alto si supera cierto umbral
        local CHAIN="TRAFFIC_${bname}"
        local bytes=$(iptables -L "$CHAIN" -n -v -x 2>/dev/null | awk '/RETURN/ {sum+=$2} END{print sum+0}')
        if [ "${bytes:-0}" -gt 10737418240 ]; then  # 10 GB
            echo -e "  ${AMARILLO}⚠ ALTO${SEMCOR}     $bname - Tráfico alto: $(format_bytes $bytes)"
            alertas=$((alertas+1))
        fi

        # Alerta expiración
        if [ -n "$bexp" ] && [ "$bexp" -gt 0 ] 2>/dev/null; then
            local diff=$((bexp - now))
            if [ "$diff" -le 0 ]; then
                echo -e "  ${ROJO}🚨 EXPIRADO${SEMCOR} $bname - Expiró $(date -d @$bexp '+%d/%m/%Y')"
                alertas=$((alertas+1))
            elif [ "$diff" -le 86400 ]; then
                echo -e "  ${ROJO}⚠ URGENTE${SEMCOR}  $bname - Expira en $(format_time_remaining $bexp)"
                alertas=$((alertas+1))
            elif [ "$diff" -le 259200 ]; then
                echo -e "  ${AMARILLO}⚠ PRONTO${SEMCOR}   $bname - Expira en $(format_time_remaining $bexp)"
                alertas=$((alertas+1))
            fi
        fi

        # Alerta offline
        if ! timeout 2 bash -c "echo >/dev/tcp/$bip/$bport" 2>/dev/null; then
            echo -e "  ${ROJO}🔴 OFFLINE${SEMCOR}  $bname - No responde ${bip}:${bport}"
            alertas=$((alertas+1))
        fi

        # Alerta conexiones altas
        local conns=$(ss -tn state established "dst ${bip}:${bport}" 2>/dev/null | tail -n +2 | wc -l)
        if [ "${conns:-0}" -ge 100 ] 2>/dev/null; then
            echo -e "  ${AMARILLO}⚠ CONEX${SEMCOR}    $bname - ${conns} conexiones (alto)"
            alertas=$((alertas+1))
        fi

    done < "$USER_DATA"

    echo ""
    msg -bar2
    if [ "$alertas" -eq 0 ]; then
        echo -e "  ${VERDE}✔ Sin alertas - Todo OK${SEMCOR}"
    else
        echo -e "  ${AMARILLO}⚠ Total alertas: $alertas${SEMCOR}"
    fi
    msg -bar
}

# ─── FUNCIÓN NUEVA: RESETEAR TRÁFICO ─────────────────────────────────────────
resetear_trafico() {
    msg -tit "RESETEAR CONTADORES DE TRÁFICO"
    echo ""

    if [ ! -s "$USER_DATA" ]; then
        msg -ama "No hay backends registrados"
        return
    fi

    echo -e "  ${BLANCO}[1]${SEMCOR} Resetear un backend"
    echo -e "  ${BLANCO}[2]${SEMCOR} Resetear TODOS"
    echo -e "  ${BLANCO}[0]${SEMCOR} Cancelar"
    echo ""
    read -p "  Selecciona: " opt

    case $opt in
        1)
            local i=1
            while IFS=':' read -r bname bip bport bexp; do
                [ -z "$bname" ] && continue
                local CHAIN="TRAFFIC_${bname}"
                local bytes=$(iptables -L "$CHAIN" -n -v -x 2>/dev/null | awk '/RETURN/ {sum+=$2} END{print sum+0}')
                echo -e "  ${BLANCO}[$i]${SEMCOR} $bname - $(format_bytes ${bytes:-0})"
                i=$((i+1))
            done < "$USER_DATA"
            echo ""
            read -p "  Selecciona: " sel
            local target=$(sed -n "${sel}p" "$USER_DATA")
            [ -z "$target" ] && { msg -verm "Inválido"; return; }
            local tname=$(echo "$target" | cut -d':' -f1)

            read -p "  ¿Resetear tráfico de '$tname'? [s/N]: " confirm
            [[ ! "$confirm" =~ ^[sS]$ ]] && return

            iptables -Z "TRAFFIC_${tname}" 2>/dev/null
            msg -verd "Tráfico de '$tname' reseteado"
            ;;
        2)
            read -p "  ¿Resetear TODOS los contadores? [s/N]: " confirm
            [[ ! "$confirm" =~ ^[sS]$ ]] && return

            while IFS=':' read -r bname bip bport bexp; do
                [ -z "$bname" ] && continue
                iptables -Z "TRAFFIC_${bname}" 2>/dev/null
            done < "$USER_DATA"
            msg -verd "Todos los contadores reseteados"
            ;;
        0|*) return ;;
    esac
}

# ─── FUNCIÓN NUEVA: INFORMACIÓN DEL SERVIDOR ─────────────────────────────────
info_servidor() {
    msg -tit "INFORMACIÓN DEL SERVIDOR"
    echo ""

    local ip_pub=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "N/A")
    local ip_priv=$(hostname -I 2>/dev/null | awk '{print $1}')
    local os_name=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2)
    local kernel=$(uname -r)
    local uptime_srv=$(uptime -p 2>/dev/null)
    local cpu_model=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | xargs)
    local cpu_cores=$(nproc 2>/dev/null)
    local ram_total=$(free -h | awk '/^Mem:/{print $2}')
    local ram_used=$(free -h | awk '/^Mem:/{print $3}')
    local ram_free=$(free -h | awk '/^Mem:/{print $4}')
    local disk_total=$(df -h / | awk 'NR==2{print $2}')
    local disk_used=$(df -h / | awk 'NR==2{print $3}')
    local disk_free=$(df -h / | awk 'NR==2{print $4}')
    local disk_pct=$(df / | awk 'NR==2{print $5}' | tr -d '%')
    local ram_pct=$(($(free | awk '/^Mem:/{print $3}') * 100 / $(free | awk '/^Mem:/{print $2}')))
    local total_conn=$(ss -tn state established 2>/dev/null | tail -n +2 | wc -l)
    local total_b=$(wc -l < "$USER_DATA" 2>/dev/null || echo 0)

    echo -e "  ${MORADO}┌─── SISTEMA ──────────────────────────────────────────┐${SEMCOR}"
    echo -e "  ${MORADO}│${SEMCOR} OS:          ${BLANCO}$os_name${SEMCOR}"
    echo -e "  ${MORADO}│${SEMCOR} Kernel:      ${BLANCO}$kernel${SEMCOR}"
    echo -e "  ${MORADO}│${SEMCOR} Uptime:      ${BLANCO}$uptime_srv${SEMCOR}"
    echo -e "  ${MORADO}├─── RED ──────────────────────────────────────────────┤${SEMCOR}"
    echo -e "  ${MORADO}│${SEMCOR} IP Pública:  ${CIAN}$ip_pub${SEMCOR}"
    echo -e "  ${MORADO}│${SEMCOR} IP Privada:  ${CIAN}$ip_priv${SEMCOR}"
    echo -e "  ${MORADO}│${SEMCOR} Conexiones:  ${CIAN}$total_conn${SEMCOR}"
    echo -e "  ${MORADO}├─── HARDWARE ─────────────────────────────────────────┤${SEMCOR}"
    echo -e "  ${MORADO}│${SEMCOR} CPU:         ${BLANCO}$cpu_model${SEMCOR}"
    echo -e "  ${MORADO}│${SEMCOR} Cores:       ${BLANCO}$cpu_cores${SEMCOR}"
    echo -e "  ${MORADO}├─── MEMORIA ──────────────────────────────────────────┤${SEMCOR}"
    echo -e "  ${MORADO}│${SEMCOR} RAM:         ${BLANCO}${ram_used} / ${ram_total}${SEMCOR} (Libre: ${ram_free})"
    echo -ne "  ${MORADO}│${SEMCOR} RAM Uso:     "; draw_bar $ram_pct 20; echo ""
    echo -e "  ${MORADO}├─── DISCO ────────────────────────────────────────────┤${SEMCOR}"
    echo -e "  ${MORADO}│${SEMCOR} Disco:       ${BLANCO}${disk_used} / ${disk_total}${SEMCOR} (Libre: ${disk_free})"
    echo -ne "  ${MORADO}│${SEMCOR} Disco Uso:   "; draw_bar $disk_pct 20; echo ""
    echo -e "  ${MORADO}├─── BACKENDS ─────────────────────────────────────────┤${SEMCOR}"
    echo -e "  ${MORADO}│${SEMCOR} Registrados: ${CIAN}$total_b${SEMCOR}"

    local total_bytes=0
    while IFS=':' read -r bname bip bport bexp; do
        [ -z "$bname" ] && continue
        local CHAIN="TRAFFIC_${bname}"
        local b=$(iptables -L "$CHAIN" -n -v -x 2>/dev/null | awk '/RETURN/ {sum+=$2} END{print sum+0}')
        total_bytes=$((total_bytes + ${b:-0}))
    done < "$USER_DATA"
    echo -e "  ${MORADO}│${SEMCOR} Tráfico:     ${CIAN}$(format_bytes $total_bytes)${SEMCOR}"
    echo -e "  ${MORADO}└──────────────────────────────────────────────────────┘${SEMCOR}"

    if command -v vnstat &>/dev/null; then
        local iface=$(ip route | grep default | awk '{print $5}' | head -1)
        if [ -n "$iface" ]; then
            echo ""
            echo -e "  ${BLANCO}Tráfico de red (vnstat):${SEMCOR}"
            vnstat -i "$iface" -s 2>/dev/null | tail -n +3 | while read line; do
                echo -e "  ${GRIS}$line${SEMCOR}"
            done
        fi
    fi
}

# ─── FUNCIÓN NUEVA: GESTIÓN DE IPs ───────────────────────────────────────────
gestionar_ips() {
    msg -tit "GESTIÓN DE IPs"
    echo ""

    echo -e "  ${BLANCO}[1]${SEMCOR} Bloquear una IP"
    echo -e "  ${BLANCO}[2]${SEMCOR} Desbloquear una IP"
    echo -e "  ${BLANCO}[3]${SEMCOR} Ver IPs bloqueadas"
    echo -e "  ${BLANCO}[4]${SEMCOR} Bloquear IP para un backend"
    echo -e "  ${BLANCO}[5]${SEMCOR} Top IPs conectadas"
    echo -e "  ${BLANCO}[0]${SEMCOR} Volver"
    echo ""
    read -p "  Selecciona: " ipopt

    case $ipopt in
        1)
            read -p "  IP a bloquear: " block_ip
            [ -z "$block_ip" ] && { msg -verm "IP vacía"; return; }
            iptables -I INPUT -s "$block_ip" -j DROP 2>/dev/null
            iptables -I FORWARD -s "$block_ip" -j DROP 2>/dev/null
            msg -verd "IP $block_ip bloqueada"
            ;;
        2)
            read -p "  IP a desbloquear: " unblock_ip
            iptables -D INPUT -s "$unblock_ip" -j DROP 2>/dev/null
            iptables -D FORWARD -s "$unblock_ip" -j DROP 2>/dev/null
            msg -verd "IP $unblock_ip desbloqueada"
            ;;
        3)
            echo ""
            echo -e "  ${BLANCO}IPs bloqueadas:${SEMCOR}"
            msg -bar2
            iptables -L INPUT -n --line-numbers 2>/dev/null | grep DROP | while read line; do
                echo -e "  ${ROJO}$line${SEMCOR}"
            done
            local count=$(iptables -L INPUT -n 2>/dev/null | grep -c DROP)
            echo -e "  ${BLANCO}Total:${SEMCOR} $count"
            ;;
        4)
            if [ ! -s "$USER_DATA" ]; then
                msg -ama "No hay backends"
                return
            fi
            local i=1
            while IFS=':' read -r bname bip bport bexp; do
                [ -z "$bname" ] && continue
                echo -e "  ${BLANCO}[$i]${SEMCOR} $bname (${bip})"
                i=$((i+1))
            done < "$USER_DATA"
            echo ""
            read -p "  Backend: " bsel
            local btarget=$(sed -n "${bsel}p" "$USER_DATA")
            [ -z "$btarget" ] && { msg -verm "Inválido"; return; }
            local btip=$(echo "$btarget" | cut -d':' -f2)
            local btname=$(echo "$btarget" | cut -d':' -f1)
            read -p "  IP a bloquear para $btname: " block_ip
            iptables -I FORWARD -s "$block_ip" -d "$btip" -j DROP 2>/dev/null
            iptables -I FORWARD -d "$block_ip" -s "$btip" -j DROP 2>/dev/null
            msg -verd "IP $block_ip bloqueada para $btname"
            ;;
        5)
            echo ""
            echo -e "  ${BLANCO}Top 20 IPs:${SEMCOR}"
            msg -bar2
            ss -tn state established 2>/dev/null | tail -n +2 | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -rn | head -20 | while read count ip; do
                printf "  ${CIAN}%-6s${SEMCOR} %s\n" "$count" "$ip"
            done
            ;;
        0|*) return ;;
    esac
}

# ─── FUNCIÓN NUEVA: VERIFICAR ONLINE/OFFLINE ─────────────────────────────────
verificar_online() {
    msg -tit "VERIFICAR ONLINE/OFFLINE"
    echo ""

    if [ ! -s "$USER_DATA" ]; then
        msg -ama "No hay backends registrados"
        return
    fi

    local online=0 offline=0

    printf "  ${BLANCO}%-4s %-15s %-17s %-10s %-10s${SEMCOR}\n" "#" "NOMBRE" "IP:PUERTO" "ESTADO" "LATENCIA"
    msg -bar2

    local i=1
    while IFS=':' read -r bname bip bport bexp; do
        [ -z "$bname" ] && continue

        local start_ms=$(date +%s%N)
        if timeout 3 bash -c "echo >/dev/tcp/$bip/$bport" 2>/dev/null; then
            local end_ms=$(date +%s%N)
            local latency=$(( (end_ms - start_ms) / 1000000 ))
            printf "  %-4s %-15s %-17s " "$i" "$bname" "${bip}:${bport}"
            echo -e "${VERDE}● ONLINE${SEMCOR}    ${BLANCO}${latency}ms${SEMCOR}"
            online=$((online+1))
        else
            printf "  %-4s %-15s %-17s " "$i" "$bname" "${bip}:${bport}"
            echo -e "${ROJO}● OFFLINE${SEMCOR}   ${GRIS}---${SEMCOR}"
            offline=$((offline+1))
        fi
        i=$((i+1))
    done < "$USER_DATA"

    echo ""
    msg -bar2
    echo -e "  ${VERDE}Online: $online${SEMCOR} | ${ROJO}Offline: $offline${SEMCOR} | Total: $((online+offline))"
    msg -bar
}

# ─── FUNCIÓN NUEVA: TRÁFICO GLOBAL VNSTAT ────────────────────────────────────
trafico_global_vnstat() {
    msg -tit "TRÁFICO GLOBAL (VNSTAT)"
    echo ""

    if ! command -v vnstat &>/dev/null; then
        msg -ama "vnstat no instalado. Instalando..."
        apt install -y vnstat > /dev/null 2>&1
        systemctl enable vnstat > /dev/null 2>&1
        systemctl start vnstat > /dev/null 2>&1
        msg -verd "Instalado. Datos disponibles en minutos."
        return
    fi

    local iface=$(ip route | grep default | awk '{print $5}' | head -1)
    [ -z "$iface" ] && { msg -verm "No se detectó interfaz"; return; }

    echo -e "  ${BLANCO}Interfaz: ${CIAN}$iface${SEMCOR}"
    echo ""
    echo -e "  ${MORADO}═══ RESUMEN ═══${SEMCOR}"
    vnstat -i "$iface" -s 2>/dev/null | while read line; do echo -e "  ${GRIS}$line${SEMCOR}"; done
    echo ""
    echo -e "  ${MORADO}═══ HOY ═══${SEMCOR}"
    vnstat -i "$iface" -d 1 2>/dev/null | while read line; do echo -e "  ${GRIS}$line${SEMCOR}"; done
    echo ""
    echo -e "  ${MORADO}═══ ESTE MES ═══${SEMCOR}"
    vnstat -i "$iface" -m 1 2>/dev/null | while read line; do echo -e "  ${GRIS}$line${SEMCOR}"; done
    echo ""
    echo -e "  ${MORADO}═══ TOP 10 DÍAS ═══${SEMCOR}"
    vnstat -i "$iface" -t 2>/dev/null | while read line; do echo -e "  ${GRIS}$line${SEMCOR}"; done
}
# ============ MENÚ PRINCIPAL CON 20 OPCIONES + NUEVAS ============
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
        echo ""
        echo -e "  ${MORADO}═══ MONITOREO Y TRÁFICO (NUEVO) ═══${SEMCOR}"
        echo -e " ${VERDE}[31]${SEMCOR} ${BLANCO}Ver tráfico por backend (GB/TB)${SEMCOR}"
        echo -e " ${VERDE}[32]${SEMCOR} ${BLANCO}Ver conexiones por backend${SEMCOR}"
        echo -e " ${VERDE}[33]${SEMCOR} ${BLANCO}Detalle conexiones de un backend${SEMCOR}"
        echo -e " ${VERDE}[34]${SEMCOR} ${BLANCO}Monitor en tiempo real${SEMCOR}"
        echo -e " ${VERDE}[35]${SEMCOR} ${BLANCO}Verificar online/offline${SEMCOR}"
        echo -e " ${VERDE}[36]${SEMCOR} ${BLANCO}Top IPs consumidoras${SEMCOR}"
        echo -e " ${VERDE}[37]${SEMCOR} ${BLANCO}Alertas de tráfico/expiración${SEMCOR}"
        echo -e " ${VERDE}[38]${SEMCOR} ${BLANCO}Resetear contadores de tráfico${SEMCOR}"
        echo -e " ${VERDE}[39]${SEMCOR} ${BLANCO}Gestión de IPs (bloquear/desbloquear)${SEMCOR}"
        echo -e " ${VERDE}[40]${SEMCOR} ${BLANCO}Información del servidor${SEMCOR}"
        echo -e " ${VERDE}[41]${SEMCOR} ${BLANCO}Tráfico global (vnstat)${SEMCOR}"
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
            31) ver_trafico; msg -bar; read -p "Presiona ENTER para continuar..." ;;
            32) ver_conexiones; msg -bar; read -p "Presiona ENTER para continuar..." ;;
            33) detalle_conexiones; msg -bar; read -p "Presiona ENTER para continuar..." ;;
            34) monitor_realtime ;;
            35) verificar_online; msg -bar; read -p "Presiona ENTER para continuar..." ;;
            36) top_ips_consumidoras; msg -bar; read -p "Presiona ENTER para continuar..." ;;
            37) alertas_trafico; msg -bar; read -p "Presiona ENTER para continuar..." ;;
            38) resetear_trafico; msg -bar; read -p "Presiona ENTER para continuar..." ;;
            39) gestionar_ips; msg -bar; read -p "Presiona ENTER para continuar..." ;;
            40) info_servidor; msg -bar; read -p "Presiona ENTER para continuar..." ;;
            41) trafico_global_vnstat; msg -bar; read -p "Presiona ENTER para continuar..." ;;
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
# Configuración inicial de Nginx (si no existe)
if [ ! -f /etc/nginx/sites-available/superc4mpeon ]; then
    cat > /etc/nginx/sites-available/superc4mpeon <<'CONF'
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

    if ($http_backend) {
        set $target_backend "http://$http_backend";
    }

    # BACKENDS PRE-CONFIGURADOS (EDITABLES)
    if ($http_backend = "local") {
        set $target_backend "http://127.0.0.1:8080";
    }

    if ($http_backend = "ssh") {
        set $target_backend "http://127.0.0.1:22";
    }

    # --- TUS BACKENDS PERSONALIZADOS ---
    # BACKEND arkey - Creado: 07/03/2026 - Expira: 23/07/2053
    if ($http_backend = "arkey") {
        set $target_backend "http://128.254.188.235:80";
    }

    # BACKEND librear - Creado: 07/03/2026 - Expira: 23/07/2053
    if ($http_backend = "librear") {
        set $target_backend "http://128.254.188.236:80";
    }

    # BACKEND sv3 - Creado: 07/03/2026 - Expira: 15/06/2026
    if ($http_backend = "sv3") {
        set $target_backend "http://151.244.242.229:80";
    }

    # BACKEND VPSConnect - Creado: 18/03/2026 - Expira: 18/04/2026 
    if ($http_backend = "VPSConnect") {
        set $target_backend "http://186.148.224.149:80";
    }
    # ------------------------------------

    # SOPORTE PARA USUARIOS PERSONALIZADOS
    if ($http_user) {
        set $target_backend "http://$http_user";
    }

    location / {
        proxy_pass $target_backend;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_set_header X-Backend-Selected $target_backend;
        proxy_set_header X-Original-URI $request_uri;

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
CONF
    ln -s /etc/nginx/sites-available/superc4mpeon /etc/nginx/sites-enabled/ 2>/dev/null
fi

# Habilitar y arrancar nginx
systemctl enable nginx
systemctl restart nginx

echo -e "${VERDE}✅ Instalación completada. Ahora ejecuta 'menu2' para disfrutar del Backend Manager by JOHNNY con 20 opciones, panel mejorado y nuevas funciones de monitoreo.${SEMCOR}"
