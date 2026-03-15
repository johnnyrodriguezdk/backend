#!/bin/bash
# ============================================================
# INSTALADOR BACKEND MANAGER PRO v6.0 - COMPLETO
# Autor: JOHNNY (@Jrcelulares)
# NO MODIFICA FUNCIONES ORIGINALES - SOLO AGREGA NUEVAS
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

clear
echo -e "${CIAN}"
echo "  ██████╗  █████╗  ██████╗██╗  ██╗███████╗███╗   ██╗██████╗ "
echo "  ██╔══██╗██╔══██╗██╔════╝██║ ██╔╝██╔════╝████╗  ██║██╔══██╗"
echo "  ██████╔╝███████║██║     █████╔╝ █████╗  ██╔██╗ ██║██║  ██║"
echo "  ██╔══██╗██╔══██║██║     ██╔═██╗ ██╔══╝  ██║╚██╗██║██║  ██║"
echo "  ██████╔╝██║  ██║╚██████╗██║  ██╗███████╗██║ ╚████║██████╔╝"
echo "  ╚═════╝ ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝╚═════╝ "
echo -e "${SEMCOR}"
echo -e "\E[41;1;37m     INSTALADOR BACKEND MANAGER PRO v6.0 by JOHNNY     \E[0m"
echo ""

# ─── BACKUP PREVIO ────────────────────────────────────────────────────────────
if [ -f /root/backendmanager.sh ]; then
    echo -e "${AMARILLO}[!] Script anterior detectado. Creando backup...${SEMCOR}"
    cp /root/backendmanager.sh /root/backendmanager.sh.backup.$(date +%Y%m%d%H%M%S)
    echo -e "${VERDE}[✓] Backup creado${SEMCOR}"
fi

# ─── INSTALAR DEPENDENCIAS ────────────────────────────────────────────────────
echo -e "${AMARILLO}[ℹ] Instalando dependencias...${SEMCOR}"
apt update -y > /dev/null 2>&1
apt install -y nginx curl wget bc net-tools iptables vnstat jq \
    gawk coreutils procps iproute2 nload iftop > /dev/null 2>&1

systemctl enable vnstat > /dev/null 2>&1
systemctl start vnstat > /dev/null 2>&1
echo -e "${VERDE}[✓] Dependencias instaladas${SEMCOR}"

# ─── CREAR DIRECTORIOS ────────────────────────────────────────────────────────
mkdir -p /etc/backendmanager/{backups,logs,traffic}
mkdir -p /root/backendmanager_backups
touch /etc/backendmanager/users.db 2>/dev/null
touch /etc/backendmanager/traffic.db 2>/dev/null
touch /etc/backendmanager/connections.log 2>/dev/null
echo -e "${VERDE}[✓] Directorios creados${SEMCOR}"

# ─── CREAR DAEMON DE MONITOREO DE TRÁFICO ─────────────────────────────────────
cat > /etc/backendmanager/traffic_monitor.sh << 'TRAFFICEOF'
#!/bin/bash
TRAFFIC_DB="/etc/backendmanager/traffic.db"
CONNECTIONS_LOG="/etc/backendmanager/connections.log"
USER_DATA="/etc/backendmanager/users.db"

while true; do
    if [ ! -f "$USER_DATA" ] || [ ! -s "$USER_DATA" ]; then
        sleep 30
        continue
    fi

    TIMESTAMP=$(date +%s)

    while IFS='|' read -r bname bip bport bexp blimit; do
        [ -z "$bname" ] && continue
        [ -z "$bip" ] && continue
        [ -z "$bport" ] && bport=80

        # Conexiones activas TCP hacia el backend
        CONN_COUNT=$(ss -tn state established "dst ${bip}:${bport}" 2>/dev/null | tail -n +2 | wc -l)

        # Tráfico por iptables (bytes)
        CHAIN_NAME="TRAFFIC_${bname}"
        if ! iptables -L "$CHAIN_NAME" -n -v > /dev/null 2>&1; then
            iptables -N "$CHAIN_NAME" 2>/dev/null
            iptables -A "$CHAIN_NAME" -d "$bip" -j RETURN 2>/dev/null
            iptables -A "$CHAIN_NAME" -s "$bip" -j RETURN 2>/dev/null
            iptables -I FORWARD -d "$bip" -j "$CHAIN_NAME" 2>/dev/null
            iptables -I FORWARD -s "$bip" -j "$CHAIN_NAME" 2>/dev/null
            iptables -I OUTPUT -d "$bip" -j "$CHAIN_NAME" 2>/dev/null
            iptables -I INPUT -s "$bip" -j "$CHAIN_NAME" 2>/dev/null
        fi

        BYTES_IN=$(iptables -L "$CHAIN_NAME" -n -v -x 2>/dev/null | awk -v ip="$bip" '$0 ~ ip && /RETURN/ {sum+=$2} END{print sum+0}')
        [ -z "$BYTES_IN" ] && BYTES_IN=0

        # Leer datos previos
        PREV_LINE=$(grep "^${bname}|" "$TRAFFIC_DB" 2>/dev/null)
        if [ -n "$PREV_LINE" ]; then
            PREV_PEAK=$(echo "$PREV_LINE" | cut -d'|' -f4)
            [ "$CONN_COUNT" -gt "${PREV_PEAK:-0}" ] 2>/dev/null && PEAK=$CONN_COUNT || PEAK=${PREV_PEAK:-0}
            sed -i "s|^${bname}|.*|${bname}|${BYTES_IN}|${CONN_COUNT}|${PEAK}|${TIMESTAMP}|" "$TRAFFIC_DB"
        else
            echo "${bname}|${BYTES_IN}|${CONN_COUNT}|${CONN_COUNT}|${TIMESTAMP}" >> "$TRAFFIC_DB"
        fi

    done < "$USER_DATA"

    # Conexiones globales puerto 80
    TOTAL_CONN=$(ss -tn state established '( dport = :80 or sport = :80 )' 2>/dev/null | tail -n +2 | wc -l)
    echo "${TIMESTAMP}|${TOTAL_CONN}" >> "$CONNECTIONS_LOG"
    tail -n 2880 "$CONNECTIONS_LOG" > /tmp/conn_trim.tmp && mv /tmp/conn_trim.tmp "$CONNECTIONS_LOG"

    sleep 30
done
TRAFFICEOF
chmod +x /etc/backendmanager/traffic_monitor.sh

# ─── SERVICIO SYSTEMD ─────────────────────────────────────────────────────────
cat > /etc/systemd/system/backend-monitor.service << 'SVCEOF'
[Unit]
Description=Backend Manager Traffic Monitor
After=network.target nginx.service

[Service]
Type=simple
ExecStart=/bin/bash /etc/backendmanager/traffic_monitor.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable backend-monitor > /dev/null 2>&1
systemctl start backend-monitor > /dev/null 2>&1
echo -e "${VERDE}[✓] Monitor de tráfico activado${SEMCOR}"

# ─── CONFIGURAR LOG NGINX ─────────────────────────────────────────────────────
cat > /etc/nginx/conf.d/backend_log.conf << 'LOGEOF'
log_format backend_traffic '$remote_addr [$time_local] '
    '$status $body_bytes_sent '
    'backend=$upstream_addr bytes=$body_bytes_sent';
LOGEOF
echo -e "${VERDE}[✓] Log de nginx configurado${SEMCOR}"

echo ""
echo -e "${AMARILLO}[ℹ] Generando script principal...${SEMCOR}"

# ============================================================
# INICIO DEL SCRIPT PRINCIPAL
# ============================================================
cat > /root/backendmanager.sh << 'MAINSCRIPT'
#!/bin/bash
# ============================================================
# BACKEND MANAGER PRO v6.0 - COMPLETO 100% FUNCIONAL
# Autor: JOHNNY (@Jrcelulares)
# 30 OPCIONES - MONITOREO - TRÁFICO - CONEXIONES
# ============================================================

# ─── COLORES ──────────────────────────────────────────────────────────────────
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
GRIS='\e[1;90m'

# ─── ARCHIVOS ────────────────────────────────────────────────────────────────
BACKEND_CONF="/etc/nginx/sites-available/backendmanager"
BACKEND_ENABLED="/etc/nginx/sites-enabled/backendmanager"
USER_DATA="/etc/backendmanager/users.db"
TRAFFIC_DB="/etc/backendmanager/traffic.db"
CONNECTIONS_LOG="/etc/backendmanager/connections.log"
BACKUP_DIR="/root/backendmanager_backups"

# ─── FUNCIONES DE MENSAJES ───────────────────────────────────────────────────
msg() {
    case $1 in
        -tit)
            echo -e "${MORADO}╔══════════════════════════════════════════════════════════╗${SEMCOR}"
            echo -e "${MORADO}║${SEMCOR} ${BLANCO}${NEGRITO}  $2${SEMCOR}"
            echo -e "${MORADO}╚══════════════════════════════════════════════════════════╝${SEMCOR}"
            ;;
        -bar)  echo -e "${CIAN}══════════════════════════════════════════════════════════${SEMCOR}" ;;
        -bar2) echo -e "${GRIS}──────────────────────────────────────────────────────────${SEMCOR}" ;;
        -verd) echo -e " ${VERDE}${NEGRITO} ✔  $2${SEMCOR}" ;;
        -verm) echo -e " ${ROJO}${NEGRITO} ✘  $2${SEMCOR}" ;;
        -ama)  echo -e " ${AMARILLO}${NEGRITO} ⚠  $2${SEMCOR}" ;;
        -info) echo -e " ${CIAN}${NEGRITO} ℹ  $2${SEMCOR}" ;;
    esac
}

# ─── FUNCIONES DE FORMATO ────────────────────────────────────────────────────
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

draw_bar() {
    local percent=$1
    local width=${2:-20}
    [ "$percent" -gt 100 ] 2>/dev/null && percent=100
    [ "$percent" -lt 0 ] 2>/dev/null && percent=0
    local filled=$((percent * width / 100))
    local empty=$((width - filled))
    local color="${VERDE}"
    [ "$percent" -ge 50 ] && color="${AMARILLO}"
    [ "$percent" -ge 80 ] && color="${ROJO}"
    printf "${color}"
    printf '█%.0s' $(seq 1 $filled 2>/dev/null)
    printf "${GRIS}"
    printf '░%.0s' $(seq 1 $empty 2>/dev/null)
    printf "${SEMCOR} ${percent}%%"
}

# ─── VERIFICAR NGINX ─────────────────────────────────────────────────────────
check_nginx() {
    if ! systemctl is-active --quiet nginx; then
        msg -ama "Nginx no está corriendo. Iniciando..."
        systemctl start nginx
        if systemctl is-active --quiet nginx; then
            msg -verd "Nginx iniciado correctamente"
        else
            msg -verm "Error al iniciar Nginx"
            return 1
        fi
    fi
    return 0
	}

# ─── REGENERAR CONFIGURACIÓN NGINX ───────────────────────────────────────────
regenerate_nginx() {
    if [ ! -f "$USER_DATA" ] || [ ! -s "$USER_DATA" ]; then
        rm -f "$BACKEND_CONF" "$BACKEND_ENABLED"
        nginx -t > /dev/null 2>&1 && systemctl reload nginx
        return
    fi

    cat > "$BACKEND_CONF" << 'NGINXHEAD'
# ============================================
# BACKEND MANAGER PRO v6.0 - Auto Generated
# NO EDITAR MANUALMENTE
# ============================================
NGINXHEAD

    local server_ip=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "0.0.0.0")

    while IFS='|' read -r bname bip bport bexp blimit; do
        [ -z "$bname" ] && continue
        [ -z "$bip" ] && continue
        [ -z "$bport" ] && bport=80

        local now=$(date +%s)
        if [ -n "$bexp" ] && [ "$bexp" -gt 0 ] 2>/dev/null; then
            if [ "$now" -ge "$bexp" ]; then
                continue
            fi
        fi

        cat >> "$BACKEND_CONF" << NGINXBLOCK

# Backend: $bname
upstream backend_${bname} {
    server ${bip}:${bport};
    keepalive 32;
}

server {
    listen 80;
    server_name ${bname}.backend.local;

    access_log /var/log/nginx/backend_${bname}_access.log;
    error_log /var/log/nginx/backend_${bname}_error.log;

    location / {
        proxy_pass http://backend_${bname};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        proxy_buffering off;
    }

    location /health {
        return 200 'OK';
        add_header Content-Type text/plain;
    }
}
NGINXBLOCK
    done < "$USER_DATA"

    ln -sf "$BACKEND_CONF" "$BACKEND_ENABLED" 2>/dev/null

    if nginx -t > /dev/null 2>&1; then
        systemctl reload nginx
        return 0
    else
        msg -verm "Error en configuración de Nginx"
        nginx -t
        return 1
    fi
}

# ─── FUNCIÓN 1: CREAR BACKEND ────────────────────────────────────────────────
crear_backend() {
    msg -tit "CREAR NUEVO BACKEND"
    echo ""

    read -p "  Nombre del backend (sin espacios): " bname
    bname=$(echo "$bname" | tr -d ' ' | tr '[:upper:]' '[:lower:]')

    if [ -z "$bname" ]; then
        msg -verm "Nombre no puede estar vacío"
        return
    fi

    if grep -q "^${bname}|" "$USER_DATA" 2>/dev/null; then
        msg -verm "El backend '$bname' ya existe"
        return
    fi

    read -p "  IP del backend: " bip
    if [ -z "$bip" ]; then
        msg -verm "IP no puede estar vacía"
        return
    fi

    # Validar formato IP
    if ! echo "$bip" | grep -qP '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$'; then
        msg -verm "Formato de IP inválido"
        return
    fi

    read -p "  Puerto del backend [80]: " bport
    bport=${bport:-80}

    if ! [[ "$bport" =~ ^[0-9]+$ ]] || [ "$bport" -lt 1 ] || [ "$bport" -gt 65535 ]; then
        msg -verm "Puerto inválido (1-65535)"
        return
    fi

    echo ""
    echo -e "  ${CIAN}Duración del servicio:${SEMCOR}"
    echo -e "  ${BLANCO}[1]${SEMCOR} 1 día"
    echo -e "  ${BLANCO}[2]${SEMCOR} 7 días"
    echo -e "  ${BLANCO}[3]${SEMCOR} 15 días"
    echo -e "  ${BLANCO}[4]${SEMCOR} 30 días"
    echo -e "  ${BLANCO}[5]${SEMCOR} 60 días"
    echo -e "  ${BLANCO}[6]${SEMCOR} 90 días"
    echo -e "  ${BLANCO}[7]${SEMCOR} Personalizado (días)"
    echo -e "  ${BLANCO}[8]${SEMCOR} Sin expiración"
    echo ""
    read -p "  Selecciona [1-8]: " dur_opt

    local exp_epoch=0
    local now=$(date +%s)
    case $dur_opt in
        1) exp_epoch=$((now + 86400)) ;;
        2) exp_epoch=$((now + 604800)) ;;
        3) exp_epoch=$((now + 1296000)) ;;
        4) exp_epoch=$((now + 2592000)) ;;
        5) exp_epoch=$((now + 5184000)) ;;
        6) exp_epoch=$((now + 7776000)) ;;
        7)
            read -p "  Cantidad de días: " custom_days
            if [[ "$custom_days" =~ ^[0-9]+$ ]] && [ "$custom_days" -gt 0 ]; then
                exp_epoch=$((now + custom_days * 86400))
            else
                msg -verm "Días inválidos"
                return
            fi
            ;;
        8) exp_epoch=0 ;;
        *)
            msg -verm "Opción inválida"
            return
            ;;
    esac

    echo ""
    echo -e "  ${CIAN}Límite de tráfico:${SEMCOR}"
    echo -e "  ${BLANCO}[1]${SEMCOR} 10 GB"
    echo -e "  ${BLANCO}[2]${SEMCOR} 50 GB"
    echo -e "  ${BLANCO}[3]${SEMCOR} 100 GB"
    echo -e "  ${BLANCO}[4]${SEMCOR} 500 GB"
    echo -e "  ${BLANCO}[5]${SEMCOR} 1 TB"
    echo -e "  ${BLANCO}[6]${SEMCOR} Personalizado (GB)"
    echo -e "  ${BLANCO}[7]${SEMCOR} Sin límite"
    echo ""
    read -p "  Selecciona [1-7]: " lim_opt

    local blimit=0
    case $lim_opt in
        1) blimit=10737418240 ;;
        2) blimit=53687091200 ;;
        3) blimit=107374182400 ;;
        4) blimit=536870912000 ;;
        5) blimit=1099511627776 ;;
        6)
            read -p "  Cantidad en GB: " custom_gb
            if [[ "$custom_gb" =~ ^[0-9]+$ ]] && [ "$custom_gb" -gt 0 ]; then
                blimit=$((custom_gb * 1073741824))
            else
                msg -verm "Valor inválido"
                return
            fi
            ;;
        7) blimit=0 ;;
        *)
            msg -verm "Opción inválida"
            return
            ;;
    esac

    # Guardar en base de datos
    echo "${bname}|${bip}|${bport}|${exp_epoch}|${blimit}" >> "$USER_DATA"

    # Crear cadena iptables para tráfico
    local CHAIN="TRAFFIC_${bname}"
    iptables -N "$CHAIN" 2>/dev/null
    iptables -A "$CHAIN" -d "$bip" -j RETURN 2>/dev/null
    iptables -A "$CHAIN" -s "$bip" -j RETURN 2>/dev/null
    iptables -I FORWARD -d "$bip" -j "$CHAIN" 2>/dev/null
    iptables -I FORWARD -s "$bip" -j "$CHAIN" 2>/dev/null
    iptables -I OUTPUT -d "$bip" -j "$CHAIN" 2>/dev/null
    iptables -I INPUT -s "$bip" -j "$CHAIN" 2>/dev/null

    # Inicializar tráfico
    echo "${bname}|0|0|0|$(date +%s)" >> "$TRAFFIC_DB"

    # Regenerar nginx
    regenerate_nginx

    echo ""
    msg -bar
    msg -verd "Backend '$bname' creado exitosamente"
    msg -bar2
    echo -e "  ${BLANCO}Nombre:${SEMCOR}      $bname"
    echo -e "  ${BLANCO}IP:${SEMCOR}          $bip"
    echo -e "  ${BLANCO}Puerto:${SEMCOR}      $bport"
    if [ "$exp_epoch" -gt 0 ]; then
        echo -e "  ${BLANCO}Expira:${SEMCOR}      $(date -d @$exp_epoch '+%d/%m/%Y %H:%M')"
        echo -e "  ${BLANCO}Restante:${SEMCOR}    $(format_time_remaining $exp_epoch)"
    else
        echo -e "  ${BLANCO}Expira:${SEMCOR}      ${VERDE}Sin expiración${SEMCOR}"
    fi
    if [ "$blimit" -gt 0 ]; then
        echo -e "  ${BLANCO}Límite:${SEMCOR}      $(format_bytes $blimit)"
    else
        echo -e "  ${BLANCO}Límite:${SEMCOR}      ${VERDE}Sin límite${SEMCOR}"
    fi
    msg -bar
}

# ─── FUNCIÓN 2: ELIMINAR BACKEND ─────────────────────────────────────────────
eliminar_backend() {
    msg -tit "ELIMINAR BACKEND"
    echo ""

    if [ ! -s "$USER_DATA" ]; then
        msg -ama "No hay backends registrados"
        return
    fi

    echo -e "  ${CIAN}Backends disponibles:${SEMCOR}"
    echo ""
    local i=1
    while IFS='|' read -r bname bip bport bexp blimit; do
        [ -z "$bname" ] && continue
        echo -e "  ${BLANCO}[$i]${SEMCOR} $bname (${bip}:${bport})"
        i=$((i+1))
    done < "$USER_DATA"
    echo -e "  ${BLANCO}[0]${SEMCOR} Cancelar"
    echo ""

    read -p "  Selecciona backend a eliminar: " sel

    if [ "$sel" = "0" ] || [ -z "$sel" ]; then
        msg -info "Operación cancelada"
        return
    fi

    local target=$(sed -n "${sel}p" "$USER_DATA")
    if [ -z "$target" ]; then
        msg -verm "Selección inválida"
        return
    fi

    local tname=$(echo "$target" | cut -d'|' -f1)
    local tip=$(echo "$target" | cut -d'|' -f2)

    echo ""
    read -p "  ¿Confirmar eliminación de '$tname'? [s/N]: " confirm
    if [[ ! "$confirm" =~ ^[sS]$ ]]; then
        msg -info "Operación cancelada"
        return
    fi

    # Eliminar de la base de datos
    sed -i "/^${tname}|/d" "$USER_DATA"
    sed -i "/^${tname}|/d" "$TRAFFIC_DB" 2>/dev/null

    # Eliminar cadenas iptables
    local CHAIN="TRAFFIC_${tname}"
    iptables -D FORWARD -d "$tip" -j "$CHAIN" 2>/dev/null
    iptables -D FORWARD -s "$tip" -j "$CHAIN" 2>/dev/null
    iptables -D OUTPUT -d "$tip" -j "$CHAIN" 2>/dev/null
    iptables -D INPUT -s "$tip" -j "$CHAIN" 2>/dev/null
    iptables -F "$CHAIN" 2>/dev/null
    iptables -X "$CHAIN" 2>/dev/null

    # Eliminar logs
    rm -f /var/log/nginx/backend_${tname}_access.log 2>/dev/null
    rm -f /var/log/nginx/backend_${tname}_error.log 2>/dev/null

    regenerate_nginx

    msg -verd "Backend '$tname' eliminado correctamente"
}

# ─── FUNCIÓN 3: LISTAR BACKENDS ──────────────────────────────────────────────
listar_backends() {
    msg -tit "LISTA DE BACKENDS"
    echo ""

    if [ ! -s "$USER_DATA" ]; then
        msg -ama "No hay backends registrados"
        return
    fi

    local total=0
    local activos=0
    local expirados=0
    local now=$(date +%s)

    printf "  ${BLANCO}%-4s %-15s %-17s %-7s %-14s %-12s${SEMCOR}\n" "#" "NOMBRE" "IP" "PUERTO" "ESTADO" "RESTANTE"
    msg -bar2

    while IFS='|' read -r bname bip bport bexp blimit; do
        [ -z "$bname" ] && continue
        total=$((total+1))

        local estado="${VERDE}● ACTIVO${SEMCOR}"
        local restante="${VERDE}∞${SEMCOR}"

        if [ -n "$bexp" ] && [ "$bexp" -gt 0 ] 2>/dev/null; then
            if [ "$now" -ge "$bexp" ]; then
                estado="${ROJO}● EXPIRADO${SEMCOR}"
                restante="${ROJO}EXPIRADO${SEMCOR}"
                expirados=$((expirados+1))
            else
                activos=$((activos+1))
                restante=$(format_time_remaining $bexp)
            fi
        else
            activos=$((activos+1))
        fi

        printf "  %-4s %-15s %-17s %-7s " "$total" "$bname" "$bip" "$bport"
        echo -e "${estado}   ${restante}"

    done < "$USER_DATA"

    echo ""
    msg -bar2
    echo -e "  ${BLANCO}Total:${SEMCOR} $total  ${VERDE}Activos: $activos${SEMCOR}  ${ROJO}Expirados: $expirados${SEMCOR}"
    msg -bar
}

# ─── FUNCIÓN 4: RENOVAR BACKEND ──────────────────────────────────────────────
renovar_backend() {
    msg -tit "RENOVAR BACKEND"
    echo ""

    if [ ! -s "$USER_DATA" ]; then
        msg -ama "No hay backends registrados"
        return
    fi

    echo -e "  ${CIAN}Backends disponibles:${SEMCOR}"
    echo ""
    local i=1
    while IFS='|' read -r bname bip bport bexp blimit; do
        [ -z "$bname" ] && continue
        local estado=""
        local now=$(date +%s)
        if [ -n "$bexp" ] && [ "$bexp" -gt 0 ] 2>/dev/null; then
            if [ "$now" -ge "$bexp" ]; then
                estado="${ROJO}[EXPIRADO]${SEMCOR}"
            else
                estado="${VERDE}[ACTIVO]${SEMCOR}"
            fi
        else
            estado="${VERDE}[SIN EXPIRACION]${SEMCOR}"
        fi
        echo -e "  ${BLANCO}[$i]${SEMCOR} $bname (${bip}:${bport}) $estado"
        i=$((i+1))
    done < "$USER_DATA"
    echo -e "  ${BLANCO}[0]${SEMCOR} Cancelar"
    echo ""

    read -p "  Selecciona backend a renovar: " sel
    if [ "$sel" = "0" ] || [ -z "$sel" ]; then
        msg -info "Operación cancelada"
        return
    fi

    local target=$(sed -n "${sel}p" "$USER_DATA")
    if [ -z "$target" ]; then
        msg -verm "Selección inválida"
        return
    fi

    local tname=$(echo "$target" | cut -d'|' -f1)
    local tip=$(echo "$target" | cut -d'|' -f2)
    local tport=$(echo "$target" | cut -d'|' -f3)
    local texp=$(echo "$target" | cut -d'|' -f4)
    local tlimit=$(echo "$target" | cut -d'|' -f5)

    echo ""
    echo -e "  ${CIAN}Renovar desde:${SEMCOR}"
    echo -e "  ${BLANCO}[1]${SEMCOR} Desde ahora"
    echo -e "  ${BLANCO}[2]${SEMCOR} Desde la expiración actual (acumular)"
    echo ""
    read -p "  Selecciona [1-2]: " renew_mode

    local base_epoch
    local now=$(date +%s)
    case $renew_mode in
        1) base_epoch=$now ;;
        2)
            if [ -n "$texp" ] && [ "$texp" -gt "$now" ] 2>/dev/null; then
                base_epoch=$texp
            else
                base_epoch=$now
            fi
            ;;
        *) msg -verm "Opción inválida"; return ;;
    esac

    echo ""
    echo -e "  ${CIAN}Duración adicional:${SEMCOR}"
    echo -e "  ${BLANCO}[1]${SEMCOR} 1 día"
    echo -e "  ${BLANCO}[2]${SEMCOR} 7 días"
    echo -e "  ${BLANCO}[3]${SEMCOR} 15 días"
    echo -e "  ${BLANCO}[4]${SEMCOR} 30 días"
    echo -e "  ${BLANCO}[5]${SEMCOR} 60 días"
    echo -e "  ${BLANCO}[6]${SEMCOR} 90 días"
    echo -e "  ${BLANCO}[7]${SEMCOR} Personalizado (días)"
    echo -e "  ${BLANCO}[8]${SEMCOR} Sin expiración"
    echo ""
    read -p "  Selecciona [1-8]: " dur_opt

    local new_exp=0
    case $dur_opt in
        1) new_exp=$((base_epoch + 86400)) ;;
        2) new_exp=$((base_epoch + 604800)) ;;
        3) new_exp=$((base_epoch + 1296000)) ;;
        4) new_exp=$((base_epoch + 2592000)) ;;
        5) new_exp=$((base_epoch + 5184000)) ;;
        6) new_exp=$((base_epoch + 7776000)) ;;
        7)
            read -p "  Cantidad de días: " custom_days
            if [[ "$custom_days" =~ ^[0-9]+$ ]] && [ "$custom_days" -gt 0 ]; then
                new_exp=$((base_epoch + custom_days * 86400))
            else
                msg -verm "Días inválidos"; return
            fi
            ;;
        8) new_exp=0 ;;
        *) msg -verm "Opción inválida"; return ;;
    esac

    # Actualizar en base de datos
    sed -i "s|^${tname}|.*|${tname}|${tip}|${tport}|${new_exp}|${tlimit}|" "$USER_DATA"

    regenerate_nginx

    echo ""
    msg -verd "Backend '$tname' renovado exitosamente"
    if [ "$new_exp" -gt 0 ]; then
        echo -e "  ${BLANCO}Nueva expiración:${SEMCOR} $(date -d @$new_exp '+%d/%m/%Y %H:%M')"
        echo -e "  ${BLANCO}Tiempo restante:${SEMCOR}  $(format_time_remaining $new_exp)"
    else
        echo -e "  ${BLANCO}Expiración:${SEMCOR} ${VERDE}Sin expiración${SEMCOR}"
    fi
}

# ─── FUNCIÓN 5: EDITAR BACKEND ───────────────────────────────────────────────
editar_backend() {
    msg -tit "EDITAR BACKEND"
    echo ""

    if [ ! -s "$USER_DATA" ]; then
        msg -ama "No hay backends registrados"
        return
    fi

    local i=1
    while IFS='|' read -r bname bip bport bexp blimit; do
        [ -z "$bname" ] && continue
        echo -e "  ${BLANCO}[$i]${SEMCOR} $bname (${bip}:${bport})"
        i=$((i+1))
    done < "$USER_DATA"
    echo -e "  ${BLANCO}[0]${SEMCOR} Cancelar"
    echo ""

    read -p "  Selecciona backend a editar: " sel
    if [ "$sel" = "0" ] || [ -z "$sel" ]; then
        msg -info "Operación cancelada"
        return
    fi

    local target=$(sed -n "${sel}p" "$USER_DATA")
    if [ -z "$target" ]; then
        msg -verm "Selección inválida"
        return
    fi

    local old_name=$(echo "$target" | cut -d'|' -f1)
    local old_ip=$(echo "$target" | cut -d'|' -f2)
    local old_port=$(echo "$target" | cut -d'|' -f3)
    local old_exp=$(echo "$target" | cut -d'|' -f4)
    local old_limit=$(echo "$target" | cut -d'|' -f5)

    echo ""
    echo -e "  ${CIAN}¿Qué deseas editar?${SEMCOR}"
    echo -e "  ${BLANCO}[1]${SEMCOR} Nombre (actual: $old_name)"
    echo -e "  ${BLANCO}[2]${SEMCOR} IP (actual: $old_ip)"
    echo -e "  ${BLANCO}[3]${SEMCOR} Puerto (actual: $old_port)"
    echo -e "  ${BLANCO}[4]${SEMCOR} Límite de tráfico (actual: $(format_bytes ${old_limit:-0}))"
    echo -e "  ${BLANCO}[5]${SEMCOR} Todo"
    echo -e "  ${BLANCO}[0]${SEMCOR} Cancelar"
    echo ""
    read -p "  Selecciona [0-5]: " edit_opt

    local new_name="$old_name"
    local new_ip="$old_ip"
    local new_port="$old_port"
    local new_limit="$old_limit"

    case $edit_opt in
        0) msg -info "Operación cancelada"; return ;;
        1)
            read -p "  Nuevo nombre [$old_name]: " input
            new_name=$(echo "${input:-$old_name}" | tr -d ' ' | tr '[:upper:]' '[:lower:]')
            if [ "$new_name" != "$old_name" ] && grep -q "^${new_name}|" "$USER_DATA" 2>/dev/null; then
                msg -verm "El nombre '$new_name' ya existe"
                return
            fi
            ;;
        2)
            read -p "  Nueva IP [$old_ip]: " input
            new_ip="${input:-$old_ip}"
            if ! echo "$new_ip" | grep -qP '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$'; then
                msg -verm "IP inválida"
                return
            fi
            ;;
        3)
            read -p "  Nuevo puerto [$old_port]: " input
            new_port="${input:-$old_port}"
            if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1 ] || [ "$new_port" -gt 65535 ]; then
                msg -verm "Puerto inválido"
                return
            fi
            ;;
        4)
            echo -e "  ${CIAN}Nuevo límite:${SEMCOR}"
            echo -e "  ${BLANCO}[1]${SEMCOR} 10 GB    ${BLANCO}[2]${SEMCOR} 50 GB    ${BLANCO}[3]${SEMCOR} 100 GB"
            echo -e "  ${BLANCO}[4]${SEMCOR} 500 GB   ${BLANCO}[5]${SEMCOR} 1 TB     ${BLANCO}[6]${SEMCOR} Personalizado"
            echo -e "  ${BLANCO}[7]${SEMCOR} Sin límite"
            read -p "  Selecciona: " lopt
            case $lopt in
                1) new_limit=10737418240 ;;
                2) new_limit=53687091200 ;;
                3) new_limit=107374182400 ;;
                4) new_limit=536870912000 ;;
                5) new_limit=1099511627776 ;;
                6)
                    read -p "  GB: " cgb
                    new_limit=$((cgb * 1073741824))
                    ;;
                7) new_limit=0 ;;
                *) msg -verm "Opción inválida"; return ;;
            esac
            ;;
        5)
            read -p "  Nuevo nombre [$old_name]: " input
            new_name=$(echo "${input:-$old_name}" | tr -d ' ' | tr '[:upper:]' '[:lower:]')
            read -p "  Nueva IP [$old_ip]: " input
            new_ip="${input:-$old_ip}"
            read -p "  Nuevo puerto [$old_port]: " input
            new_port="${input:-$old_port}"
            echo -e "  ${CIAN}Límite de tráfico:${SEMCOR}"
            echo -e "  ${BLANCO}[1]${SEMCOR} 10GB  ${BLANCO}[2]${SEMCOR} 50GB  ${BLANCO}[3]${SEMCOR} 100GB  ${BLANCO}[4]${SEMCOR} 500GB  ${BLANCO}[5]${SEMCOR} 1TB  ${BLANCO}[6]${SEMCOR} Custom  ${BLANCO}[7]${SEMCOR} Sin límite"
            read -p "  Selecciona: " lopt
            case $lopt in
                1) new_limit=10737418240 ;; 2) new_limit=53687091200 ;;
                3) new_limit=107374182400 ;; 4) new_limit=536870912000 ;;
                5) new_limit=1099511627776 ;;
                6) read -p "  GB: " cgb; new_limit=$((cgb * 1073741824)) ;;
                7) new_limit=0 ;; *) new_limit="$old_limit" ;;
            esac
            ;;
        *) msg -verm "Opción inválida"; return ;;
    esac

    # Actualizar iptables si cambió IP
    if [ "$new_ip" != "$old_ip" ] || [ "$new_name" != "$old_name" ]; then
        local OLD_CHAIN="TRAFFIC_${old_name}"
        iptables -D FORWARD -d "$old_ip" -j "$OLD_CHAIN" 2>/dev/null
        iptables -D FORWARD -s "$old_ip" -j "$OLD_CHAIN" 2>/dev/null
        iptables -D OUTPUT -d "$old_ip" -j "$OLD_CHAIN" 2>/dev/null
        iptables -D INPUT -s "$old_ip" -j "$OLD_CHAIN" 2>/dev/null
        iptables -F "$OLD_CHAIN" 2>/dev/null
        iptables -X "$OLD_CHAIN" 2>/dev/null

        local NEW_CHAIN="TRAFFIC_${new_name}"
        iptables -N "$NEW_CHAIN" 2>/dev/null
        iptables -A "$NEW_CHAIN" -d "$new_ip" -j RETURN 2>/dev/null
        iptables -A "$NEW_CHAIN" -s "$new_ip" -j RETURN 2>/dev/null
        iptables -I FORWARD -d "$new_ip" -j "$NEW_CHAIN" 2>/dev/null
        iptables -I FORWARD -s "$new_ip" -j "$NEW_CHAIN" 2>/dev/null
        iptables -I OUTPUT -d "$new_ip" -j "$NEW_CHAIN" 2>/dev/null
        iptables -I INPUT -s "$new_ip" -j "$NEW_CHAIN" 2>/dev/null

        # Actualizar traffic db
        sed -i "s|^${old_name}||${new_name}|" "$TRAFFIC_DB" 2>/dev/null
    fi

    sed -i "s|^${old_name}|.*|${new_name}|${new_ip}|${new_port}|${old_exp}|${new_limit}|" "$USER_DATA"

    regenerate_nginx

    echo ""
    msg -verd "Backend actualizado correctamente"
    echo -e "  ${BLANCO}Nombre:${SEMCOR}  $new_name"
    echo -e "  ${BLANCO}IP:${SEMCOR}      $new_ip"
    echo -e "  ${BLANCO}Puerto:${SEMCOR}  $new_port"
    echo -e "  ${BLANCO}Límite:${SEMCOR}  $(format_bytes ${new_limit:-0})"
}

# ─── FUNCIÓN 6: ESTADO DE BACKENDS ───────────────────────────────────────────
estado_backends() {
    msg -tit "ESTADO DE TODOS LOS BACKENDS"
    echo ""

    if [ ! -s "$USER_DATA" ]; then
        msg -ama "No hay backends registrados"
        return
    fi

    local now=$(date +%s)

    while IFS='|' read -r bname bip bport bexp blimit; do
        [ -z "$bname" ] && continue

        echo -e "  ${MORADO}┌──────────────────────────────────────────────────┐${SEMCOR}"
        echo -e "  ${MORADO}│${SEMCOR} ${BLANCO}${NEGRITO} $bname ${SEMCOR}"
        echo -e "  ${MORADO}├──────────────────────────────────────────────────┤${SEMCOR}"

        # Estado de conexión
        local ping_ok=false
        if timeout 3 bash -c "echo >/dev/tcp/$bip/$bport" 2>/dev/null; then
            ping_ok=true
            echo -e "  ${MORADO}│${SEMCOR}  Estado:      ${VERDE}● ONLINE${SEMCOR}"
        else
            echo -e "  ${MORADO}│${SEMCOR}  Estado:      ${ROJO}● OFFLINE${SEMCOR}"
        fi

        echo -e "  ${MORADO}│${SEMCOR}  IP:          ${bip}:${bport}"

        # Expiración
        if [ -n "$bexp" ] && [ "$bexp" -gt 0 ] 2>/dev/null; then
            if [ "$now" -ge "$bexp" ]; then
                echo -e "  ${MORADO}│${SEMCOR}  Expiración:  ${ROJO}EXPIRADO ($(date -d @$bexp '+%d/%m/%Y'))${SEMCOR}"
            else
                echo -e "  ${MORADO}│${SEMCOR}  Expiración:  $(date -d @$bexp '+%d/%m/%Y %H:%M')"
                echo -e "  ${MORADO}│${SEMCOR}  Restante:    $(format_time_remaining $bexp)"
            fi
        else
            echo -e "  ${MORADO}│${SEMCOR}  Expiración:  ${VERDE}Sin expiración${SEMCOR}"
        fi

        # Conexiones activas
        local conns=$(ss -tn state established "dst ${bip}:${bport}" 2>/dev/null | tail -n +2 | wc -l)
        local conns_from=$(ss -tn state established "src ${bip}:${bport}" 2>/dev/null | tail -n +2 | wc -l)
        local total_conns=$((conns + conns_from))
        echo -e "  ${MORADO}│${SEMCOR}  Conexiones:  ${CIAN}${total_conns} activas${SEMCOR} (→${conns} ←${conns_from})"

        # Tráfico
        local traffic_line=$(grep "^${bname}|" "$TRAFFIC_DB" 2>/dev/null)
        local bytes_used=0
        local peak_conn=0
        if [ -n "$traffic_line" ]; then
            bytes_used=$(echo "$traffic_line" | cut -d'|' -f2)
            peak_conn=$(echo "$traffic_line" | cut -d'|' -f4)
        fi

        # Tráfico desde iptables (más preciso)
        local CHAIN="TRAFFIC_${bname}"
        local ipt_bytes=$(iptables -L "$CHAIN" -n -v -x 2>/dev/null | awk '/RETURN/ {sum+=$2} END{print sum+0}')
        [ "${ipt_bytes:-0}" -gt "${bytes_used:-0}" ] 2>/dev/null && bytes_used=$ipt_bytes

        echo -e "  ${MORADO}│${SEMCOR}  Tráfico:     $(format_bytes ${bytes_used:-0})"
        echo -e "  ${MORADO}│${SEMCOR}  Peak conex:  ${peak_conn:-0}"

        # Barra de tráfico si hay límite
        if [ -n "$blimit" ] && [ "${blimit:-0}" -gt 0 ] 2>/dev/null; then
            local pct=0
            if [ "${bytes_used:-0}" -gt 0 ] 2>/dev/null; then
                pct=$((bytes_used * 100 / blimit))
            fi
            echo -ne "  ${MORADO}│${SEMCOR}  Uso:         "
            draw_bar $pct 20
            echo -e " ($(format_bytes ${bytes_used:-0}) / $(format_bytes $blimit))"
        else
            echo -e "  ${MORADO}│${SEMCOR}  Límite:      ${VERDE}Sin límite${SEMCOR}"
        fi

        echo -e "  ${MORADO}└──────────────────────────────────────────────────┘${SEMCOR}"
        echo ""

    done < "$USER_DATA"
}

# ─── FUNCIÓN 7: VER TRÁFICO POR BACKEND (GB/TB) ──────────────────────────────
ver_trafico() {
    msg -tit "TRÁFICO POR BACKEND (GB/TB)"
    echo ""

    if [ ! -s "$USER_DATA" ]; then
        msg -ama "No hay backends registrados"
        return
    fi

    printf "  ${BLANCO}%-4s %-15s %-15s %-15s %-10s %-8s${SEMCOR}\n" "#" "NOMBRE" "TRÁFICO USADO" "LÍMITE" "USO %" "ESTADO"
    msg -bar2

    local i=1
    local total_traffic=0

    while IFS='|' read -r bname bip bport bexp blimit; do
        [ -z "$bname" ] && continue

        # Obtener bytes de iptables
        local CHAIN="TRAFFIC_${bname}"
        local bytes=$(iptables -L "$CHAIN" -n -v -x 2>/dev/null | awk '/RETURN/ {sum+=$2} END{print sum+0}')
        [ -z "$bytes" ] && bytes=0

        # También verificar traffic.db
        local db_bytes=$(grep "^${bname}|" "$TRAFFIC_DB" 2>/dev/null | cut -d'|' -f2)
        [ "${db_bytes:-0}" -gt "$bytes" ] 2>/dev/null && bytes=$db_bytes

        total_traffic=$((total_traffic + bytes))

        local limit_str="${VERDE}∞${SEMCOR}"
        local pct_str="-"
        local estado="${VERDE}OK${SEMCOR}"

        if [ -n "$blimit" ] && [ "${blimit:-0}" -gt 0 ] 2>/dev/null; then
            limit_str="$(format_bytes $blimit)"
            local pct=0
            [ "$bytes" -gt 0 ] && pct=$((bytes * 100 / blimit))
            pct_str="${pct}%"

            if [ "$pct" -ge 100 ]; then
                estado="${ROJO}EXCEDIDO${SEMCOR}"
            elif [ "$pct" -ge 80 ]; then
                estado="${AMARILLO}ALTO${SEMCOR}"
            elif [ "$pct" -ge 50 ]; then
                estado="${AMARILLO}MEDIO${SEMCOR}"
            fi
        fi

        printf "  %-4s %-15s " "$i" "$bname"
        printf "%-15s " "$(format_bytes $bytes)"
        echo -e "${limit_str}          ${pct_str}       ${estado}"

        i=$((i+1))
    done < "$USER_DATA"

    echo ""
    msg -bar2
    echo -e "  ${BLANCO}Tráfico total del servidor:${SEMCOR} ${CIAN}$(format_bytes $total_traffic)${SEMCOR}"

    # Tráfico del sistema con vnstat
    if command -v vnstat &>/dev/null; then
        echo ""
        echo -e "  ${BLANCO}Estadísticas vnstat (interfaz principal):${SEMCOR}"
        local iface=$(ip route | grep default | awk '{print $5}' | head -1)
        if [ -n "$iface" ]; then
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

# ─── FUNCIÓN 8: VER CONEXIONES POR BACKEND ───────────────────────────────────
ver_conexiones() {
    msg -tit "CONEXIONES ACTIVAS POR BACKEND"
    echo ""

    if [ ! -s "$USER_DATA" ]; then
        msg -ama "No hay backends registrados"
        return
    fi

    local total_global=0

    printf "  ${BLANCO}%-4s %-15s %-17s %-12s %-10s %-10s${SEMCOR}\n" "#" "NOMBRE" "IP:PUERTO" "CONECTADOS" "PEAK" "ESTADO"
    msg -bar2

    local i=1
    while IFS='|' read -r bname bip bport bexp blimit; do
        [ -z "$bname" ] && continue

        # Conexiones entrantes al backend
        local conn_to=$(ss -tn state established "dst ${bip}:${bport}" 2>/dev/null | tail -n +2 | wc -l)
        # Conexiones salientes del backend
        local conn_from=$(ss -tn state established "src ${bip}:${bport}" 2>/dev/null | tail -n +2 | wc -l)
        local total=$((conn_to + conn_from))
        total_global=$((total_global + total))

        # Peak desde traffic.db
        local peak=$(grep "^${bname}|" "$TRAFFIC_DB" 2>/dev/null | cut -d'|' -f4)
        [ -z "$peak" ] && peak=0
        [ "$total" -gt "$peak" ] && peak=$total

        # Actualizar peak en traffic.db
        if grep -q "^${bname}|" "$TRAFFIC_DB" 2>/dev/null; then
            local old_line=$(grep "^${bname}|" "$TRAFFIC_DB")
            local f2=$(echo "$old_line" | cut -d'|' -f2)
            local f5=$(echo "$old_line" | cut -d'|' -f5)
            sed -i "s|^${bname}|.*|${bname}|${f2}|${total}|${peak}|${f5}|" "$TRAFFIC_DB"
        fi

        local estado="${VERDE}● OK${SEMCOR}"
        if [ "$total" -eq 0 ]; then
            estado="${GRIS}● SIN CONEX${SEMCOR}"
        elif [ "$total" -ge 100 ]; then
            estado="${ROJO}● ALTO${SEMCOR}"
        elif [ "$total" -ge 50 ]; then
            estado="${AMARILLO}● MEDIO${SEMCOR}"
        fi

        printf "  %-4s %-15s %-17s " "$i" "$bname" "${bip}:${bport}"
        echo -e "${CIAN}${total}${SEMCOR}           ${BLANCO}${peak}${SEMCOR}         ${estado}"

        i=$((i+1))
    done < "$USER_DATA"

    echo ""
    msg -bar2
    echo -e "  ${BLANCO}Total conexiones globales:${SEMCOR} ${CIAN}${total_global}${SEMCOR}"

    # Conexiones globales del servidor
    local srv_established=$(ss -tn state established 2>/dev/null | tail -n +2 | wc -l)
    local srv_timewait=$(ss -tn state time-wait 2>/dev/null | tail -n +2 | wc -l)
    local srv_listen=$(ss -tln 2>/dev/null | tail -n +2 | wc -l)
    echo -e "  ${BLANCO}Servidor:${SEMCOR} Established: ${srv_established} | Time-Wait: ${srv_timewait} | Listening: ${srv_listen}"
    msg -bar
}

# ─── FUNCIÓN 9: DETALLE DE CONEXIONES DE UN BACKEND ──────────────────────────
detalle_conexiones() {
    msg -tit "DETALLE DE CONEXIONES POR BACKEND"
    echo ""

    if [ ! -s "$USER_DATA" ]; then
        msg -ama "No hay backends registrados"
        return
    fi

    local i=1
    while IFS='|' read -r bname bip bport bexp blimit; do
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

    local tname=$(echo "$target" | cut -d'|' -f1)
    local tip=$(echo "$target" | cut -d'|' -f2)
    local tport=$(echo "$target" | cut -d'|' -f3)

    echo ""
    msg -tit "CONEXIONES DE: $tname ($tip:$tport)"
    echo ""

    echo -e "  ${BLANCO}${NEGRITO}Conexiones entrantes (clientes → backend):${SEMCOR}"
        msg -bar2
    local conn_list=$(ss -tn state established "dst ${tip}:${tport}" 2>/dev/null | tail -n +2)
    if [ -z "$conn_list" ]; then
        echo -e "  ${GRIS}No hay conexiones entrantes activas${SEMCOR}"
    else
        printf "  ${BLANCO}%-22s %-22s %-12s${SEMCOR}\n" "ORIGEN" "DESTINO" "ESTADO"
        msg -bar2
        echo "$conn_list" | while read -r state recv send local_addr peer_addr rest; do
            printf "  %-22s %-22s ${VERDE}%-12s${SEMCOR}\n" "$peer_addr" "$local_addr" "ESTABLISHED"
        done

        echo ""
        echo -e "  ${BLANCO}Resumen por IP de origen:${SEMCOR}"
        msg -bar2
        echo "$conn_list" | awk '{print $4}' | cut -d: -f1 | sort | uniq -c | sort -rn | head -20 | while read count ip; do
            printf "  ${CIAN}%-6s${SEMCOR} conexiones desde ${BLANCO}%s${SEMCOR}\n" "$count" "$ip"
        done
    fi

    echo ""
    echo -e "  ${BLANCO}${NEGRITO}Conexiones salientes (backend → clientes):${SEMCOR}"
    msg -bar2
    local conn_out=$(ss -tn state established "src ${tip}:${tport}" 2>/dev/null | tail -n +2)
    if [ -z "$conn_out" ]; then
        echo -e "  ${GRIS}No hay conexiones salientes activas${SEMCOR}"
    else
        echo "$conn_out" | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -rn | head -20 | while read count ip; do
            printf "  ${CIAN}%-6s${SEMCOR} conexiones hacia ${BLANCO}%s${SEMCOR}\n" "$count" "$ip"
        done
    fi

    local total_in=$(echo "$conn_list" | grep -c . 2>/dev/null)
    local total_out=$(echo "$conn_out" | grep -c . 2>/dev/null)
    [ -z "$conn_list" ] && total_in=0
    [ -z "$conn_out" ] && total_out=0

    echo ""
    msg -bar2
    echo -e "  ${BLANCO}Total:${SEMCOR} Entrantes: ${CIAN}${total_in}${SEMCOR} | Salientes: ${CIAN}${total_out}${SEMCOR} | Total: ${VERDE}$((total_in + total_out))${SEMCOR}"
    msg -bar
}

# ─── FUNCIÓN 10: MONITOR EN TIEMPO REAL ──────────────────────────────────────
monitor_realtime() {
    msg -tit "MONITOR EN TIEMPO REAL"
    echo ""
    echo -e "  ${AMARILLO}Presiona Ctrl+C para salir${SEMCOR}"
    echo ""
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

        # Info del servidor
        local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1)
        local mem_total=$(free -m | awk '/^Mem:/{print $2}')
        local mem_used=$(free -m | awk '/^Mem:/{print $3}')
        local mem_pct=$((mem_used * 100 / mem_total))
        local disk_pct=$(df / | awk 'NR==2{print $5}' | tr -d '%')
        local load=$(uptime | awk -F'load average:' '{print $2}' | xargs)
        local total_conn=$(ss -tn state established 2>/dev/null | tail -n +2 | wc -l)

        echo -e "  ${BLANCO}SERVIDOR${SEMCOR}"
        echo -ne "  CPU:  "; draw_bar ${cpu_usage:-0} 20; echo ""
        echo -ne "  RAM:  "; draw_bar $mem_pct 20; echo " (${mem_used}/${mem_total} MB)"
        echo -ne "  Disco:"; draw_bar $disk_pct 20; echo ""
        echo -e "  Load: ${load}  |  Conexiones totales: ${CIAN}${total_conn}${SEMCOR}"
        echo ""

        # Backends
        printf "  ${BLANCO}%-15s %-8s %-10s %-15s %-12s %-10s${SEMCOR}\n" "BACKEND" "ESTADO" "CONEX" "TRÁFICO" "LÍMITE" "RESTANTE"
        echo -e "  ${GRIS}─────────────────────────────────────────────────────────────────────────${SEMCOR}"

        if [ -s "$USER_DATA" ]; then
            while IFS='|' read -r bname bip bport bexp blimit; do
                [ -z "$bname" ] && continue

                # Estado
                local estado="${ROJO}OFF${SEMCOR}"
                if timeout 1 bash -c "echo >/dev/tcp/$bip/$bport" 2>/dev/null; then
                    estado="${VERDE}ON ${SEMCOR}"
                fi

                # Conexiones
                local conns=$(ss -tn state established "dst ${bip}:${bport}" 2>/dev/null | tail -n +2 | wc -l)
                local conns2=$(ss -tn state established "src ${bip}:${bport}" 2>/dev/null | tail -n +2 | wc -l)
                local total_c=$((conns + conns2))

                # Tráfico
                local CHAIN="TRAFFIC_${bname}"
                local bytes=$(iptables -L "$CHAIN" -n -v -x 2>/dev/null | awk '/RETURN/ {sum+=$2} END{print sum+0}')
                [ -z "$bytes" ] && bytes=0

                local limit_str="∞"
                if [ -n "$blimit" ] && [ "${blimit:-0}" -gt 0 ] 2>/dev/null; then
                    limit_str="$(format_bytes $blimit)"
                fi

                # Tiempo restante
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
                printf "%-12s " "$limit_str"
                echo -e "$rest_str"

            done < "$USER_DATA"
        else
            echo -e "  ${GRIS}No hay backends registrados${SEMCOR}"
        fi

        echo ""
        echo -e "  ${GRIS}Actualizando cada 5 segundos... Ctrl+C para salir${SEMCOR}"
        sleep 5
    done
}

# ─── FUNCIÓN 11: BACKUP ──────────────────────────────────────────────────────
hacer_backup() {
    msg -tit "CREAR BACKUP"
    echo ""

    local fecha=$(date +%Y%m%d_%H%M%S)
    local backup_file="${BACKUP_DIR}/backup_${fecha}.tar.gz"

    mkdir -p "$BACKUP_DIR"

    # Crear directorio temporal
    local tmp_dir="/tmp/bkm_backup_${fecha}"
    mkdir -p "$tmp_dir"

    # Copiar archivos
    cp "$USER_DATA" "$tmp_dir/users.db" 2>/dev/null
    cp "$TRAFFIC_DB" "$tmp_dir/traffic.db" 2>/dev/null
    cp "$BACKEND_CONF" "$tmp_dir/nginx_backends.conf" 2>/dev/null
    cp "$CONNECTIONS_LOG" "$tmp_dir/connections.log" 2>/dev/null

    # Exportar iptables
    iptables-save > "$tmp_dir/iptables_rules.txt" 2>/dev/null

    # Info del backup
    cat > "$tmp_dir/backup_info.txt" << BKINFO
Backup Backend Manager Pro v6.0
Fecha: $(date '+%d/%m/%Y %H:%M:%S')
Servidor: $(hostname)
IP: $(curl -s ifconfig.me 2>/dev/null)
Backends: $(wc -l < "$USER_DATA" 2>/dev/null || echo 0)
BKINFO

    # Comprimir
    tar -czf "$backup_file" -C /tmp "bkm_backup_${fecha}" 2>/dev/null
    rm -rf "$tmp_dir"

    if [ -f "$backup_file" ]; then
        local size=$(du -h "$backup_file" | cut -f1)
        msg -verd "Backup creado exitosamente"
        echo -e "  ${BLANCO}Archivo:${SEMCOR}  $backup_file"
        echo -e "  ${BLANCO}Tamaño:${SEMCOR}   $size"
        echo -e "  ${BLANCO}Fecha:${SEMCOR}    $(date '+%d/%m/%Y %H:%M:%S')"
    else
        msg -verm "Error al crear backup"
    fi
}

# ─── FUNCIÓN 12: RESTAURAR BACKUP ────────────────────────────────────────────
restaurar_backup() {
    msg -tit "RESTAURAR BACKUP"
    echo ""

    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A $BACKUP_DIR/*.tar.gz 2>/dev/null)" ]; then
        msg -ama "No hay backups disponibles"
        return
    fi

    echo -e "  ${CIAN}Backups disponibles:${SEMCOR}"
    echo ""
    local i=1
    local backups=()
    for f in $(ls -t ${BACKUP_DIR}/*.tar.gz 2>/dev/null); do
        local fname=$(basename "$f")
        local fsize=$(du -h "$f" | cut -f1)
        local fdate=$(echo "$fname" | grep -oP '\d{8}_\d{6}')
        echo -e "  ${BLANCO}[$i]${SEMCOR} $fname (${fsize})"
        backups+=("$f")
        i=$((i+1))
    done
    echo -e "  ${BLANCO}[0]${SEMCOR} Cancelar"
    echo ""

    read -p "  Selecciona backup: " sel
    [ "$sel" = "0" ] || [ -z "$sel" ] && return

    local idx=$((sel - 1))
    if [ -z "${backups[$idx]}" ]; then
        msg -verm "Selección inválida"
        return
    fi

    local selected="${backups[$idx]}"

    echo ""
    read -p "  ¿Confirmar restauración? Se sobrescribirán datos actuales [s/N]: " confirm
    [[ ! "$confirm" =~ ^[sS]$ ]] && { msg -info "Cancelado"; return; }

    # Backup actual antes de restaurar
    hacer_backup

    # Extraer
    local tmp_dir="/tmp/bkm_restore_$$"
    mkdir -p "$tmp_dir"
    tar -xzf "$selected" -C "$tmp_dir" 2>/dev/null

    local extract_dir=$(find "$tmp_dir" -maxdepth 1 -type d | tail -1)

    # Restaurar archivos
    [ -f "$extract_dir/users.db" ] && cp "$extract_dir/users.db" "$USER_DATA"
    [ -f "$extract_dir/traffic.db" ] && cp "$extract_dir/traffic.db" "$TRAFFIC_DB"
    [ -f "$extract_dir/connections.log" ] && cp "$extract_dir/connections.log" "$CONNECTIONS_LOG"

    # Restaurar iptables
    if [ -f "$extract_dir/iptables_rules.txt" ]; then
        iptables-restore < "$extract_dir/iptables_rules.txt" 2>/dev/null
    fi

    rm -rf "$tmp_dir"

    # Regenerar nginx
    regenerate_nginx

    msg -verd "Backup restaurado exitosamente"
    echo -e "  ${BLANCO}Desde:${SEMCOR} $(basename $selected)"
}

# ─── FUNCIÓN 13: LIMPIAR EXPIRADOS ───────────────────────────────────────────
limpiar_expirados() {
    msg -tit "LIMPIAR BACKENDS EXPIRADOS"
    echo ""

    if [ ! -s "$USER_DATA" ]; then
        msg -ama "No hay backends registrados"
        return
    fi

    local now=$(date +%s)
    local count=0
    local expired_list=""

    while IFS='|' read -r bname bip bport bexp blimit; do
        [ -z "$bname" ] && continue
        if [ -n "$bexp" ] && [ "$bexp" -gt 0 ] 2>/dev/null; then
            if [ "$now" -ge "$bexp" ]; then
                expired_list="${expired_list}${bname} (${bip}:${bport}) - Expiró: $(date -d @$bexp '+%d/%m/%Y')\n"
                count=$((count+1))
            fi
        fi
    done < "$USER_DATA"

    if [ "$count" -eq 0 ]; then
        msg -verd "No hay backends expirados"
        return
    fi

    echo -e "  ${ROJO}Backends expirados encontrados: $count${SEMCOR}"
    echo ""
    echo -e "$expired_list"
    echo ""
    read -p "  ¿Eliminar todos los expirados? [s/N]: " confirm
    [[ ! "$confirm" =~ ^[sS]$ ]] && { msg -info "Cancelado"; return; }

    # Hacer backup primero
    hacer_backup

    while IFS='|' read -r bname bip bport bexp blimit; do
        [ -z "$bname" ] && continue
        if [ -n "$bexp" ] && [ "$bexp" -gt 0 ] 2>/dev/null; then
            if [ "$now" -ge "$bexp" ]; then
                # Limpiar iptables
                local CHAIN="TRAFFIC_${bname}"
                iptables -D FORWARD -d "$bip" -j "$CHAIN" 2>/dev/null
				                iptables -D FORWARD -s "$bip" -j "$CHAIN" 2>/dev/null
                iptables -D OUTPUT -d "$bip" -j "$CHAIN" 2>/dev/null
                iptables -D INPUT -s "$bip" -j "$CHAIN" 2>/dev/null
                iptables -F "$CHAIN" 2>/dev/null
                iptables -X "$CHAIN" 2>/dev/null

                # Limpiar logs
                rm -f /var/log/nginx/backend_${bname}_access.log 2>/dev/null
                rm -f /var/log/nginx/backend_${bname}_error.log 2>/dev/null

                # Eliminar de traffic.db
                sed -i "/^${bname}|/d" "$TRAFFIC_DB" 2>/dev/null

                msg -verd "Eliminado: $bname"
            fi
        fi
    done < "$USER_DATA"

    # Eliminar de users.db
    local tmp_file="/tmp/users_clean_$$"
    while IFS='|' read -r bname bip bport bexp blimit; do
        [ -z "$bname" ] && continue
        if [ -n "$bexp" ] && [ "$bexp" -gt 0 ] 2>/dev/null; then
            [ "$now" -ge "$bexp" ] && continue
        fi
        echo "${bname}|${bip}|${bport}|${bexp}|${blimit}" >> "$tmp_file"
    done < "$USER_DATA"

    if [ -f "$tmp_file" ]; then
        mv "$tmp_file" "$USER_DATA"
    else
        > "$USER_DATA"
    fi

    regenerate_nginx
    echo ""
    msg -verd "$count backends expirados eliminados"
}

# ─── FUNCIÓN 14: RESETEAR TRÁFICO ────────────────────────────────────────────
resetear_trafico() {
    msg -tit "RESETEAR CONTADORES DE TRÁFICO"
    echo ""

    if [ ! -s "$USER_DATA" ]; then
        msg -ama "No hay backends registrados"
        return
    fi

    echo -e "  ${CIAN}Opciones:${SEMCOR}"
    echo -e "  ${BLANCO}[1]${SEMCOR} Resetear un backend específico"
    echo -e "  ${BLANCO}[2]${SEMCOR} Resetear TODOS los backends"
    echo -e "  ${BLANCO}[0]${SEMCOR} Cancelar"
    echo ""
    read -p "  Selecciona [0-2]: " opt

    case $opt in
        0) return ;;
        1)
            local i=1
            while IFS='|' read -r bname bip bport bexp blimit; do
                [ -z "$bname" ] && continue
                local CHAIN="TRAFFIC_${bname}"
                local bytes=$(iptables -L "$CHAIN" -n -v -x 2>/dev/null | awk '/RETURN/ {sum+=$2} END{print sum+0}')
                echo -e "  ${BLANCO}[$i]${SEMCOR} $bname - Tráfico actual: $(format_bytes ${bytes:-0})"
                i=$((i+1))
            done < "$USER_DATA"
            echo ""
            read -p "  Selecciona backend: " sel
            [ -z "$sel" ] && return

            local target=$(sed -n "${sel}p" "$USER_DATA")
            [ -z "$target" ] && { msg -verm "Selección inválida"; return; }

            local tname=$(echo "$target" | cut -d'|' -f1)

            read -p "  ¿Confirmar reset de tráfico para '$tname'? [s/N]: " confirm
            [[ ! "$confirm" =~ ^[sS]$ ]] && return

            # Reset iptables counters
            local CHAIN="TRAFFIC_${tname}"
            iptables -Z "$CHAIN" 2>/dev/null

            # Reset en traffic.db
            local now=$(date +%s)
            if grep -q "^${tname}|" "$TRAFFIC_DB" 2>/dev/null; then
                sed -i "s|^${tname}|.*|${tname}|0|0|0|${now}|" "$TRAFFIC_DB"
            fi

            msg -verd "Tráfico de '$tname' reseteado a 0"
            ;;
        2)
            read -p "  ¿Confirmar reset de TODOS los contadores? [s/N]: " confirm
            [[ ! "$confirm" =~ ^[sS]$ ]] && return

            while IFS='|' read -r bname bip bport bexp blimit; do
                [ -z "$bname" ] && continue
                local CHAIN="TRAFFIC_${bname}"
                iptables -Z "$CHAIN" 2>/dev/null
            done < "$USER_DATA"

            local now=$(date +%s)
            > "$TRAFFIC_DB"
            while IFS='|' read -r bname bip bport bexp blimit; do
                [ -z "$bname" ] && continue
                echo "${bname}|0|0|0|${now}" >> "$TRAFFIC_DB"
            done < "$USER_DATA"

            msg -verd "Todos los contadores reseteados"
            ;;
        *) msg -verm "Opción inválida" ;;
    esac
}

# ─── FUNCIÓN 15: ESTADO DE NGINX ─────────────────────────────────────────────
estado_nginx() {
    msg -tit "ESTADO DE NGINX"
    echo ""

    if systemctl is-active --quiet nginx; then
        echo -e "  Estado:    ${VERDE}● ACTIVO${SEMCOR}"
    else
        echo -e "  Estado:    ${ROJO}● INACTIVO${SEMCOR}"
    fi

    local pid=$(pgrep -f "nginx: master" | head -1)
    [ -n "$pid" ] && echo -e "  PID:       ${pid}"

    local workers=$(pgrep -c "nginx: worker" 2>/dev/null)
    echo -e "  Workers:   ${workers:-0}"

    local uptime_nginx=""
    if [ -n "$pid" ]; then
        local start=$(stat -c %Y /proc/$pid 2>/dev/null)
        if [ -n "$start" ]; then
            local now=$(date +%s)
            local diff=$((now - start))
            local days=$((diff / 86400))
            local hours=$(( (diff % 86400) / 3600 ))
            local mins=$(( (diff % 3600) / 60 ))
            uptime_nginx="${days}d ${hours}h ${mins}m"
        fi
    fi
    echo -e "  Uptime:    ${uptime_nginx:-N/A}"

    echo ""
    echo -e "  ${BLANCO}Test de configuración:${SEMCOR}"
    nginx -t 2>&1 | while read line; do
        echo -e "  ${GRIS}$line${SEMCOR}"
    done

    echo ""
    echo -e "  ${BLANCO}Puertos en uso por Nginx:${SEMCOR}"
    ss -tlnp | grep nginx | awk '{print "  " $4}' | sort -u

    echo ""
    echo -e "  ${BLANCO}Opciones:${SEMCOR}"
    echo -e "  ${BLANCO}[1]${SEMCOR} Reiniciar Nginx"
    echo -e "  ${BLANCO}[2]${SEMCOR} Recargar configuración"
    echo -e "  ${BLANCO}[3]${SEMCOR} Detener Nginx"
    echo -e "  ${BLANCO}[4]${SEMCOR} Iniciar Nginx"
    echo -e "  ${BLANCO}[0]${SEMCOR} Volver"
    echo ""
    read -p "  Selecciona: " nopt

    case $nopt in
        1) systemctl restart nginx && msg -verd "Nginx reiniciado" || msg -verm "Error al reiniciar" ;;
        2) nginx -t > /dev/null 2>&1 && systemctl reload nginx && msg -verd "Configuración recargada" || msg -verm "Error en configuración" ;;
        3) systemctl stop nginx && msg -verd "Nginx detenido" || msg -verm "Error al detener" ;;
        4) systemctl start nginx && msg -verd "Nginx iniciado" || msg -verm "Error al iniciar" ;;
        0|*) return ;;
    esac
}

# ─── FUNCIÓN 16: VER LOGS ────────────────────────────────────────────────────
ver_logs() {
    msg -tit "VISOR DE LOGS"
    echo ""

    echo -e "  ${BLANCO}[1]${SEMCOR} Logs de acceso de Nginx (general)"
    echo -e "  ${BLANCO}[2]${SEMCOR} Logs de error de Nginx (general)"
    echo -e "  ${BLANCO}[3]${SEMCOR} Logs de un backend específico"
    echo -e "  ${BLANCO}[4]${SEMCOR} Log de conexiones del monitor"
    echo -e "  ${BLANCO}[5]${SEMCOR} Log del sistema (syslog)"
    echo -e "  ${BLANCO}[0]${SEMCOR} Volver"
    echo ""
    read -p "  Selecciona: " lopt

    case $lopt in
        1)
            msg -info "Últimas 50 líneas de /var/log/nginx/access.log"
            msg -bar2
            tail -50 /var/log/nginx/access.log 2>/dev/null || msg -ama "Log no encontrado"
            ;;
        2)
            msg -info "Últimas 50 líneas de /var/log/nginx/error.log"
            msg -bar2
            tail -50 /var/log/nginx/error.log 2>/dev/null || msg -ama "Log no encontrado"
            ;;
        3)
            if [ ! -s "$USER_DATA" ]; then
                msg -ama "No hay backends"
                return
            fi
            local i=1
            while IFS='|' read -r bname bip bport bexp blimit; do
                [ -z "$bname" ] && continue
                echo -e "  ${BLANCO}[$i]${SEMCOR} $bname"
                i=$((i+1))
            done < "$USER_DATA"
            echo ""
            read -p "  Selecciona: " bsel
            local btarget=$(sed -n "${bsel}p" "$USER_DATA" | cut -d'|' -f1)
            [ -z "$btarget" ] && { msg -verm "Inválido"; return; }

            echo ""
            echo -e "  ${BLANCO}[1]${SEMCOR} Access log"
            echo -e "  ${BLANCO}[2]${SEMCOR} Error log"
            read -p "  Selecciona: " logtype
            case $logtype in
                1) tail -50 /var/log/nginx/backend_${btarget}_access.log 2>/dev/null || msg -ama "Sin log" ;;
                2) tail -50 /var/log/nginx/backend_${btarget}_error.log 2>/dev/null || msg -ama "Sin log" ;;
                *) msg -verm "Inválido" ;;
            esac
            ;;
        4)
            msg -info "Últimas 50 entradas del monitor de conexiones"
            msg -bar2
            tail -50 "$CONNECTIONS_LOG" 2>/dev/null | while IFS='|' read ts conns; do
                [ -z "$ts" ] && continue
                echo -e "  $(date -d @$ts '+%d/%m %H:%M:%S' 2>/dev/null) - ${CIAN}${conns}${SEMCOR} conexiones"
            done
            ;;
        5)
            msg -info "Últimas 50 líneas de syslog"
            msg -bar2
            tail -50 /var/log/syslog 2>/dev/null || journalctl -n 50 --no-pager 2>/dev/null
            ;;
        0|*) return ;;
    esac
}

# ─── FUNCIÓN 17: BLOQUEAR/DESBLOQUEAR IP ─────────────────────────────────────
gestionar_ips() {
    msg -tit "GESTIÓN DE IPs (BLOQUEAR/DESBLOQUEAR)"
    echo ""

    echo -e "  ${BLANCO}[1]${SEMCOR} Bloquear una IP"
    echo -e "  ${BLANCO}[2]${SEMCOR} Desbloquear una IP"
    echo -e "  ${BLANCO}[3]${SEMCOR} Ver IPs bloqueadas"
    echo -e "  ${BLANCO}[4]${SEMCOR} Bloquear IP para un backend específico"
    echo -e "  ${BLANCO}[5]${SEMCOR} Ver top IPs conectadas"
    echo -e "  ${BLANCO}[0]${SEMCOR} Volver"
    echo ""
    read -p "  Selecciona: " ipopt

    case $ipopt in
        1)
            read -p "  IP a bloquear: " block_ip
            if [ -z "$block_ip" ]; then
                msg -verm "IP vacía"
                return
            fi
            iptables -I INPUT -s "$block_ip" -j DROP 2>/dev/null
            iptables -I FORWARD -s "$block_ip" -j DROP 2>/dev/null
            msg -verd "IP $block_ip bloqueada globalmente"
            ;;
        2)
            read -p "  IP a desbloquear: " unblock_ip
            iptables -D INPUT -s "$unblock_ip" -j DROP 2>/dev/null
            iptables -D FORWARD -s "$unblock_ip" -j DROP 2>/dev/null
            msg -verd "IP $unblock_ip desbloqueada"
            ;;
        3)
            echo ""
            echo -e "  ${BLANCO}IPs bloqueadas (DROP):${SEMCOR}"
            msg -bar2
            iptables -L INPUT -n --line-numbers | grep DROP | while read line; do
                echo -e "  ${ROJO}$line${SEMCOR}"
            done
            local count=$(iptables -L INPUT -n | grep -c DROP)
            echo ""
            echo -e "  ${BLANCO}Total bloqueadas:${SEMCOR} $count"
            ;;
        4)
            if [ ! -s "$USER_DATA" ]; then
                msg -ama "No hay backends"
                return
            fi
            local i=1
            while IFS='|' read -r bname bip bport bexp blimit; do
                [ -z "$bname" ] && continue
                echo -e "  ${BLANCO}[$i]${SEMCOR} $bname (${bip})"
                i=$((i+1))
            done < "$USER_DATA"
            echo ""
            read -p "  Backend: " bsel
            local btarget=$(sed -n "${bsel}p" "$USER_DATA")
            [ -z "$btarget" ] &&            { msg -verm "Inválido"; return; }
            local btip=$(echo "$btarget" | cut -d'|' -f2)
            local btport=$(echo "$btarget" | cut -d'|' -f3)
            local btname=$(echo "$btarget" | cut -d'|' -f1)

            read -p "  IP a bloquear para $btname: " block_ip
            iptables -I FORWARD -s "$block_ip" -d "$btip" -j DROP 2>/dev/null
            iptables -I FORWARD -d "$block_ip" -s "$btip" -j DROP 2>/dev/null
            msg -verd "IP $block_ip bloqueada para backend $btname"
            ;;
        5)
            echo ""
            echo -e "  ${BLANCO}Top 20 IPs con más conexiones activas:${SEMCOR}"
            msg -bar2
            ss -tn state established 2>/dev/null | tail -n +2 | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -rn | head -20 | while read count ip; do
                local bar_len=$((count / 2))
                [ "$bar_len" -gt 30 ] && bar_len=30
                local bar=$(printf '█%.0s' $(seq 1 $bar_len 2>/dev/null))
                printf "  ${CIAN}%-6s${SEMCOR} ${BLANCO}%-18s${SEMCOR} ${VERDE}%s${SEMCOR}\n" "$count" "$ip" "$bar"
            done
            ;;
        0|*) return ;;
    esac
}

# ─── FUNCIÓN 18: INFORMACIÓN DEL SERVIDOR ────────────────────────────────────
info_servidor() {
    msg -tit "INFORMACIÓN DEL SERVIDOR"
    echo ""

    local ip_pub=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || curl -s --max-time 5 icanhazip.com 2>/dev/null || echo "N/A")
    local ip_priv=$(hostname -I 2>/dev/null | awk '{print $1}')
    local hostname_srv=$(hostname)
    local os_name=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2)
    local kernel=$(uname -r)
    local arch=$(uname -m)
    local uptime_srv=$(uptime -p 2>/dev/null || uptime)
    local cpu_model=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | xargs)
    local cpu_cores=$(nproc 2>/dev/null)
    local ram_total=$(free -h | awk '/^Mem:/{print $2}')
    local ram_used=$(free -h | awk '/^Mem:/{print $3}')
    local ram_free=$(free -h | awk '/^Mem:/{print $4}')
    local swap_total=$(free -h | awk '/^Swap:/{print $2}')
    local swap_used=$(free -h | awk '/^Swap:/{print $3}')
    local disk_total=$(df -h / | awk 'NR==2{print $2}')
    local disk_used=$(df -h / | awk 'NR==2{print $3}')
    local disk_free=$(df -h / | awk 'NR==2{print $4}')
    local disk_pct=$(df / | awk 'NR==2{print $5}' | tr -d '%')
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | xargs)
    local total_backends=$(wc -l < "$USER_DATA" 2>/dev/null || echo 0)
    local total_conn=$(ss -tn state established 2>/dev/null | tail -n +2 | wc -l)
    local iface=$(ip route | grep default | awk '{print $5}' | head -1)

    echo -e "  ${MORADO}┌─── SISTEMA ──────────────────────────────────────────┐${SEMCOR}"
    echo -e "  ${MORADO}│${SEMCOR} Hostname:    ${BLANCO}$hostname_srv${SEMCOR}"
    echo -e "  ${MORADO}│${SEMCOR} OS:          ${BLANCO}$os_name${SEMCOR}"
    echo -e "  ${MORADO}│${SEMCOR} Kernel:      ${BLANCO}$kernel${SEMCOR}"
    echo -e "  ${MORADO}│${SEMCOR} Arch:        ${BLANCO}$arch${SEMCOR}"
    echo -e "  ${MORADO}│${SEMCOR} Uptime:      ${BLANCO}$uptime_srv${SEMCOR}"
    echo -e "  ${MORADO}├─── RED ──────────────────────────────────────────────┤${SEMCOR}"
    echo -e "  ${MORADO}│${SEMCOR} IP Pública:  ${CIAN}$ip_pub${SEMCOR}"
    echo -e "  ${MORADO}│${SEMCOR} IP Privada:  ${CIAN}$ip_priv${SEMCOR}"
    echo -e "  ${MORADO}│${SEMCOR} Interfaz:    ${BLANCO}$iface${SEMCOR}"
    echo -e "  ${MORADO}│${SEMCOR} Conexiones:  ${CIAN}$total_conn${SEMCOR}"
    echo -e "  ${MORADO}├─── HARDWARE ─────────────────────────────────────────┤${SEMCOR}"
    echo -e "  ${MORADO}│${SEMCOR} CPU:         ${BLANCO}$cpu_model${SEMCOR}"
    echo -e "  ${MORADO}│${SEMCOR} Cores:       ${BLANCO}$cpu_cores${SEMCOR}"
    echo -e "  ${MORADO}│${SEMCOR} Load:        ${BLANCO}$load_avg${SEMCOR}"
    echo -e "  ${MORADO}├─── MEMORIA ──────────────────────────────────────────┤${SEMCOR}"
    echo -e "  ${MORADO}│${SEMCOR} RAM:         ${BLANCO}${ram_used} / ${ram_total}${SEMCOR} (Libre: ${ram_free})"
    echo -ne "  ${MORADO}│${SEMCOR} RAM Uso:     "; local ram_pct=$(($(free | awk '/^Mem:/{print $3}') * 100 / $(free | awk '/^Mem:/{print $2}'))); draw_bar $ram_pct 20; echo ""
    echo -e "  ${MORADO}│${SEMCOR} Swap:        ${BLANCO}${swap_used} / ${swap_total}${SEMCOR}"
    echo -e "  ${MORADO}├─── DISCO ────────────────────────────────────────────┤${SEMCOR}"
    echo -e "  ${MORADO}│${SEMCOR} Disco:       ${BLANCO}${disk_used} / ${disk_total}${SEMCOR} (Libre: ${disk_free})"
    echo -ne "  ${MORADO}│${SEMCOR} Disco Uso:   "; draw_bar $disk_pct 20; echo ""
    echo -e "  ${MORADO}├─── BACKENDS ─────────────────────────────────────────┤${SEMCOR}"
    echo -e "  ${MORADO}│${SEMCOR} Registrados: ${CIAN}$total_backends${SEMCOR}"

    # Contar activos y expirados
    local activos=0 expirados=0 now=$(date +%s)
    while IFS='|' read -r bname bip bport bexp blimit; do
        [ -z "$bname" ] && continue
        if [ -n "$bexp" ] && [ "$bexp" -gt 0 ] 2>/dev/null; then
            [ "$now" -ge "$bexp" ] && expirados=$((expirados+1)) || activos=$((activos+1))
        else
            activos=$((activos+1))
        fi
    done < "$USER_DATA"
    echo -e "  ${MORADO}│${SEMCOR} Activos:     ${VERDE}$activos${SEMCOR}"
    echo -e "  ${MORADO}│${SEMCOR} Expirados:   ${ROJO}$expirados${SEMCOR}"

    # Tráfico total
    local total_bytes=0
    while IFS='|' read -r bname bip bport bexp blimit; do
        [ -z "$bname" ] && continue
        local CHAIN="TRAFFIC_${bname}"
        local b=$(iptables -L "$CHAIN" -n -v -x 2>/dev/null | awk '/RETURN/ {sum+=$2} END{print sum+0}')
        total_bytes=$((total_bytes + ${b:-0}))
    done < "$USER_DATA"
    echo -e "  ${MORADO}│${SEMCOR} Tráfico:     ${CIAN}$(format_bytes $total_bytes)${SEMCOR}"
    echo -e "  ${MORADO}└──────────────────────────────────────────────────────┘${SEMCOR}"

    # vnstat
    if command -v vnstat &>/dev/null && [ -n "$iface" ]; then
        echo ""
        echo -e "  ${BLANCO}Tráfico de red (vnstat - $iface):${SEMCOR}"
        msg -bar2
        vnstat -i "$iface" -s 2>/dev/null | tail -n +3 | while read line; do
            echo -e "  ${GRIS}$line${SEMCOR}"
        done
    fi
}

# ─── FUNCIÓN 19: EXPORTAR DATOS ──────────────────────────────────────────────
exportar_datos() {
    msg -tit "EXPORTAR DATOS"
    echo ""

    echo -e "  ${BLANCO}[1]${SEMCOR} Exportar lista de backends (TXT)"
    echo -e "  ${BLANCO}[2]${SEMCOR} Exportar lista de backends (CSV)"
    echo -e "  ${BLANCO}[3]${SEMCOR} Exportar reporte completo"
    echo -e "  ${BLANCO}[4]${SEMCOR} Exportar tráfico"
    echo -e "  ${BLANCO}[0]${SEMCOR} Volver"
    echo ""
    read -p "  Selecciona: " eopt

    local fecha=$(date +%Y%m%d_%H%M%S)
    local now=$(date +%s)

    case $eopt in
        1)
            local file="/root/backends_${fecha}.txt"
            echo "=== BACKENDS - $(date) ===" > "$file"
            echo "" >> "$file"
            printf "%-15s %-17s %-7s %-12s %-15s %-15s\n" "NOMBRE" "IP" "PUERTO" "ESTADO" "TRÁFICO" "EXPIRA" >> "$file"
            echo "────────────────────────────────────────────────────────────────────────────────" >> "$file"
            while IFS='|' read -r bname bip bport bexp blimit; do
                [ -z "$bname" ] && continue
                local est="ACTIVO"
                local exp_str="Sin exp."
                if [ -n "$bexp" ] && [ "$bexp" -gt 0 ] 2>/dev/null; then
                    [ "$now" -ge "$bexp" ] && est="EXPIRADO"
                    exp_str=$(date -d @$bexp '+%d/%m/%Y' 2>/dev/null)
                fi
                local CHAIN="TRAFFIC_${bname}"
                local bytes=$(iptables -L "$CHAIN" -n -v -x 2>/dev/null | awk '/RETURN/ {sum+=$2} END{print sum+0}')
                printf "%-15s %-17s %-7s %-12s %-15s %-15s\n" "$bname" "$bip" "$bport" "$est" "$(format_bytes ${bytes:-0})" "$exp_str" >> "$file"
            done < "$USER_DATA"
            msg -verd "Exportado: $file"
            ;;
        2)
            local file="/root/backends_${fecha}.csv"
            echo "nombre,ip,puerto,estado,trafico_bytes,limite_bytes,expiracion" > "$file"
            while IFS='|' read -r bname bip bport bexp blimit; do
                [ -z "$bname" ] && continue
                local est="activo"
                if [ -n "$bexp" ] && [ "$bexp" -gt 0 ] 2>/dev/null; then
                    [ "$now" -ge "$bexp" ] && est="expirado"
                fi
                local CHAIN="TRAFFIC_${bname}"
                local bytes=$(iptables -L "$CHAIN" -n -v -x 2>/dev/null | awk '/RETURN/ {sum+=$2} END{print sum+0}')
                echo "${bname},${bip},${bport},${est},${bytes:-0},${blimit:-0},${bexp:-0}" >> "$file"
            done < "$USER_DATA"
            msg -verd "Exportado: $file"
            ;;
        3)
            local file="/root/reporte_${fecha}.txt"
            {
                echo "╔══════════════════════════════════════════════════════════╗"
                echo "║     REPORTE BACKEND MANAGER PRO - $(date '+%d/%m/%Y %H:%M')      ║"
                echo "╚══════════════════════════════════════════════════════════╝"
                echo ""
                echo "SERVIDOR: $(hostname) | IP: $(curl -s --max-time 5 ifconfig.me 2>/dev/null)"
                echo "OS: $(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2)"
                echo "Uptime: $(uptime -p 2>/dev/null)"
                echo ""
                echo "═══ BACKENDS ═══"
                local total=0 act=0 exp=0
                while IFS='|' read -r bname bip bport bexp blimit; do
                    [ -z "$bname" ] && continue
                    total=$((total+1))
                    local est="ACTIVO"; local conns=$(ss -tn state established "dst ${bip}:${bport}" 2>/dev/null | tail -n +2 | wc -l)
                    local CHAIN="TRAFFIC_${bname}"
                    local bytes=$(iptables -L "$CHAIN" -n -v -x 2>/dev/null | awk '/RETURN/ {sum+=$2} END{print sum+0}')
                    if [ -n "$bexp" ] && [ "$bexp" -gt 0 ] 2>/dev/null; then
                        [ "$now" -ge "$bexp" ] && { est="EXPIRADO"; exp=$((exp+1)); } || act=$((act+1))
                    else
                        act=$((act+1))
                    fi
                    echo "  $bname | $bip:$bport | $est | Conex: $conns | Tráfico: $(format_bytes ${bytes:-0})"
                done < "$USER_DATA"
                echo ""
                echo "Total: $total | Activos: $act | Expirados: $exp"
                echo ""
                echo "═══ RECURSOS ═══"
                echo "CPU: $(top -bn1 | grep 'Cpu(s)' | awk '{print $2}')%"
                echo "RAM: $(free -h | awk '/^Mem:/{print $3 "/" $2}')"
                echo "Disco: $(df -h / | awk 'NR==2{print $3 "/" $2 " (" $5 ")"}')"
                echo ""
                echo "═══ FIN DEL REPORTE ═══"
            } > "$file"
            msg -verd "Reporte exportado: $file"
            ;;
        4)
            local file="/root/trafico_${fecha}.csv"
            echo "backend,bytes_usados,conexiones,peak_conexiones,timestamp" > "$file"
            while IFS='|' read -r bname bip bport bexp blimit; do
                [ -z "$bname" ] && continue
                local CHAIN="TRAFFIC_${bname}"
                local bytes=$(iptables -L "$CHAIN" -n -v -x 2>/dev/null | awk '/RETURN/ {sum+=$2} END{print sum+0}')
                local conns=$(ss -tn state established "dst ${bip}:${bport}" 2>/dev/null | tail -n +2 | wc -l)
                local peak=$(grep "^${bname}|" "$TRAFFIC_DB" 2>/dev/null | cut -d'|' -f4)
                echo "${bname},${bytes:-0},${conns},${peak:-0},$(date +%s)" >> "$file"
            done < "$USER_DATA"
            msg -verd "Tráfico exportado: $file"
            ;;
        0|*) return ;;
    esac
}

# ─── FUNCIÓN 20: CAMBIAR LÍMITE DE TRÁFICO ───────────────────────────────────
cambiar_limite() {
    msg -tit "CAMBIAR LÍMITE DE TRÁFICO"
    echo ""

    if [ ! -s "$USER_DATA" ]; then
        msg -ama "No hay backends registrados"
        return
    fi

    local i=1
    while IFS='|' read -r bname bip bport bexp blimit; do
        [ -z "$bname" ] && continue
        local lim_str="${VERDE}Sin límite${SEMCOR}"
        [ -n "$blimit" ] && [ "${blimit:-0}" -gt 0 ] 2>/dev/null && lim_str="$(format_bytes $blimit)"
        echo -e "  ${BLANCO}[$i]${SEMCOR} $bname - Límite actual: $lim_str"
        i=$((i+1))
    done < "$USER_DATA"
    echo -e "  ${BLANCO}[0]${SEMCOR} Cancelar"
    echo ""
    read -p "  Selecciona: " sel
    [ "$sel" = "0" ] || [ -z "$sel" ] && return

    local target=$(sed -n "${sel}p" "$USER_DATA")
    [ -z "$target" ] && { msg -verm "Inválido"; return; }

    local tname=$(echo "$target" | cut -d'|' -f1)
    local tip=$(echo "$target" | cut -d'|' -f2)
    local tport=$(echo "$target" | cut -d'|' -f3)
    local texp=$(echo "$target" | cut -d'|' -f4)

    echo ""
    echo -e "  ${CIAN}Nuevo límite para $tname:${SEMCOR}"
    echo -e "  ${BLANCO}[1]${SEMCOR} 10 GB     ${BLANCO}[2]${SEMCOR} 50 GB     ${BLANCO}[3]${SEMCOR} 100 GB"
    echo -e "  ${BLANCO}[4]${SEMCOR} 500 GB    ${BLANCO}[5]${SEMCOR} 1 TB      ${BLANCO}[6]${SEMCOR} 5 TB"
    echo -e "  ${BLANCO}[7]${SEMCOR} 10 TB     ${BLANCO}[8]${SEMCOR} Personalizado (GB)"
    echo -e "  ${BLANCO}[9]${SEMCOR} Sin límite"
    echo ""
    read -p "  Selecciona: " lopt

    local new_limit=0
    case $lopt in
        1) new_limit=10737418240 ;;
        2) new_limit=53687091200 ;;
        3) new_limit=107374182400 ;;
        4) new_limit=536870912000 ;;
        5) new_limit=1099511627776 ;;
        6) new_limit=5497558138880 ;;
        7) new_limit=10995116277760 ;;
        8)
            read -p "  Cantidad en GB: " cgb
            if [[ "$cgb" =~ ^[0-9]+$ ]] && [ "$cgb" -gt 0 ]; then
                new_limit=$((cgb * 1073741824))
            else
                msg -verm "Valor inválido"; return
            fi
            ;;
        9) new_limit=0 ;;
        *) msg -verm "Opción inválida"; return ;;
    esac

    sed -i "s|^${tname}|.*|${tname}|${tip}|${tport}|${texp}|${new_limit}|" "$USER_DATA"

    echo ""
    if [ "$new_limit" -gt 0 ]; then
        msg -verd "Límite de '$tname' cambiado a $(format_bytes $new_limit)"
    else
        msg -verd "Límite de '$tname' eliminado (sin límite)"
    fi
}

# ─── FUNCIÓN 21: VERIFICAR BACKENDS ONLINE/OFFLINE ───────────────────────────
verificar_online() {
    msg -tit "VERIFICAR ESTADO ONLINE/OFFLINE"
    echo ""

    if [ ! -s "$USER_DATA" ]; then
        msg -ama "No hay backends registrados"
        return
    fi

    local online=0 offline=0 total=0

    printf "  ${BLANCO}%-4s %-15s %-17s %-10s %-12s${SEMCOR}\n" "#" "NOMBRE" "IP:PUERTO" "ESTADO" "LATENCIA"
    msg -bar2

    local i=1
    while IFS='|' read -r bname bip bport bexp blimit; do
        [ -z "$bname" ] && continue
        total=$((total+1))

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
    echo -e "  ${BLANCO}Total:${SEMCOR} $total | ${VERDE}Online: $online${SEMCOR} | ${ROJO}Offline: $offline${SEMCOR}"
    msg -bar
}

# ─── FUNCIÓN 22: REINICIAR MONITOR ───────────────────────────────────────────
reiniciar_monitor() {
    msg -tit "REINICIAR SERVICIO DE MONITOREO"
    echo ""

    echo -e "  ${BLANCO}Estado actual:${SEMCOR}"
    if systemctl is-active --quiet backend-monitor; then
        echo -e "  ${VERDE}● Monitor activo${SEMCOR}"
    else
        echo -e "  ${ROJO}● Monitor inactivo${SEMCOR}"
    fi

    echo ""
    echo -e "  ${BLANCO}[1]${SEMCOR} Reiniciar monitor"
    echo -e "  ${BLANCO}[2]${SEMCOR} Detener monitor"
    echo -e "  ${BLANCO}[3]${SEMCOR} Iniciar monitor"
    echo -e "  ${BLANCO}[4]${SEMCOR} Ver logs del monitor"
    echo -e "  ${BLANCO}[0]${SEMCOR} Volver"
    echo ""
    read -p "  Selecciona: " mopt

    case $mopt in
        1) systemctl restart backend-monitor && msg -verd "Monitor reiniciado" || msg -verm "Error" ;;
        2) systemctl stop backend-monitor && msg -verd "Monitor detenido" || msg -verm "Error" ;;
        3) systemctl start backend-monitor && msg -verd "Monitor iniciado" || msg -verm "Error" ;;
        4) journalctl -u backend-monitor -n 30 --no-pager 2>/dev/null ;;
        0|*) return ;;
    esac
}

# ─── FUNCIÓN 23: ELIMINAR TODOS LOS BACKENDS ─────────────────────────────────
eliminar_todos() {
    msg -tit "ELIMINAR TODOS LOS BACKENDS"
    echo ""

    if [ ! -s "$USER_DATA" ]; then
        msg -ama "No hay backends registrados"
        return
    fi

    local total=$(wc -l < "$USER_DATA")
    echo -e "  ${ROJO}¡ADVERTENCIA! Se eliminarán $total backends${SEMCOR}"
    echo ""
    read -p "  Escribe 'CONFIRMAR' para continuar: " confirm
    [ "$confirm" != "CONFIRMAR" ] && { msg -info "Cancelado"; return; }

    # Backup primero
    hacer_backup

    # Limpiar iptables
    while IFS='|' read -r bname bip bport bexp blimit; do
        [ -z "$bname" ] && continue
        local CHAIN="TRAFFIC_${bname}"
        iptables -D FORWARD -d "$bip" -j "$CHAIN" 2>/dev/null
        iptables -D FORWARD -s "$bip" -j "$CHAIN" 2>/dev/null
        iptables -D OUTPUT -d "$bip" -j "$CHAIN" 2>/dev/null
        iptables -D INPUT -s "$bip" -j "$CHAIN" 2>/dev/null
        iptables -F "$CHAIN" 2>/dev/null
        iptables -X "$CHAIN" 2>/dev/null
        rm -f /var/log/nginx/backend_${bname}_*.log 2>/dev/null
    done < "$USER_DATA"

    > "$USER_DATA"
    > "$TRAFFIC_DB"
    regenerate_nginx

    msg -verd "Todos los backends eliminados"
}

# ============================================================
# MENÚ PRINCIPAL
# ============================================================
menu_principal() {
    while true; do
        clear
        echo -e "${CIAN}"
        echo "  ╔══════════════════════════════════════════════════════════╗"
        echo "  ║       BACKEND MANAGER PRO v6.0 - by JOHNNY             ║"
        echo "  ║       Telegram: @Jrcelulares                           ║"
        echo "  ╚══════════════════════════════════════════════════════════╝"
        echo -e "${SEMCOR}"

        # Resumen rápido
        local total_b=$(wc -l < "$USER_DATA" 2>/dev/null || echo 0)
        local total_c=$(ss -tn state established '( dport = :80 or sport = :80 )' 2>/dev/null | tail -n +2 | wc -l)
        local nginx_st="${ROJO}OFF${SEMCOR}"
        systemctl is-active --quiet nginx && nginx_st="${VERDE}ON${SEMCOR}"
        local monitor_st="${ROJO}OFF${SEMCOR}"
        systemctl is-active --quiet backend-monitor && monitor_st="${VERDE}ON${SEMCOR}"

        echo -e "  ${GRIS}Backends: ${BLANCO}${total_b}${GRIS} | Conexiones: ${BLANCO}${total_c}${GRIS} | Nginx: ${nginx_st}${GRIS} | Monitor: ${monitor_st}${SEMCOR}"
        echo ""

        echo -e "  ${MORADO}═══ GESTIÓN DE BACKENDS ═══${SEMCOR}"
        echo -e "  ${BLANCO}[1]${SEMCOR}  Crear backend"
        echo -e "  ${BLANCO}[2]${SEMCOR}  Eliminar backend"
        echo -e "  ${BLANCO}[3]${SEMCOR}  Listar backends"
        echo -e "  ${BLANCO}[4]${SEMCOR}  Renovar backend"
        echo -e "  ${BLANCO}[5]${SEMCOR}  Editar backend"
        echo -e "  ${BLANCO}[6]${SEMCOR}  Estado de backends"
        echo ""
        echo -e "  ${MORADO}═══ MONITOREO Y TRÁFICO ═══${SEMCOR}"
        echo -e "  ${BLANCO}[7]${SEMCOR}  Ver tráfico por backend (GB/TB)"
        echo -e "  ${BLANCO}[8]${SEMCOR}  Ver conexiones por backend"
        echo -e "  ${BLANCO}[9]${SEMCOR}  Detalle conexiones de un backend"
        echo -e "  ${BLANCO}[10]${SEMCOR} Monitor en tiempo real"
        echo -e "  ${BLANCO}[11]${SEMCOR} Verificar online/offline"
        echo ""
        echo -e "  ${MORADO}═══ ADMINISTRACIÓN ═══${SEMCOR}"
        echo -e "  ${BLANCO}[12]${SEMCOR} Cambiar límite de tráfico"
        echo -e "  ${BLANCO}[13]${SEMCOR} Resetear contadores de tráfico"
        echo -e "  ${BLANCO}[14]${SEMCOR} Limpiar backends expirados"
        echo -e "  ${BLANCO}[15]${SEMCOR} Eliminar TODOS los backends"
        echo ""
        echo -e "  ${MORADO}═══ HERRAMIENTAS ═══${SEMCOR}"
        echo -e "  ${BLANCO}[16]${SEMCOR} Estado de Nginx"
        echo -e "  ${BLANCO}[17]${SEMCOR} Ver logs"
        echo -e "  ${BLANCO}[18]${SEMCOR} Gestión de IPs (bloquear/desbloquear)"
        echo -e "  ${BLANCO}[19]${SEMCOR} Información del servidor"
        echo -e "  ${BLANCO}[20]${SEMCOR} Reiniciar monitor de tráfico"
        echo ""
        echo -e "  ${MORADO}═══ DATOS ═══${SEMCOR}"
        echo -e "  ${BLANCO}[21]${SEMCOR} Crear backup"
        echo -e "  ${BLANCO}[22]${SEMCOR} Restaurar backup"
        echo -e "  ${BLANCO}[23]${SEMCOR} Exportar datos"
        echo ""
        echo -e "  ${MORADO}═══ AVANZADO ═══${SEMCOR}"
        echo -e "  ${BLANCO}[24]${SEMCOR} Resumen de tráfico global (vnstat)"
        echo -e "  ${BLANCO}[25]${SEMCOR} Top IPs consumidoras"
        echo -e "  ${BLANCO}[26]${SEMCOR} Historial de conexiones"
        echo -e "  ${BLANCO}[27]${SEMCOR} Regenerar configuración Nginx"
        echo -e "  ${BLANCO}[28]${SEMCOR} Verificar integridad del sistema"
        echo -e "  ${BLANCO}[29]${SEMCOR} Alertas de tráfico excedido"
        echo -e "  ${BLANCO}[30]${SEMCOR} Acerca de / Actualizar"
        echo ""
        echo -e "  ${ROJO}[0]${SEMCOR}  Salir"
        echo ""
        msg -bar2
        read -p "  Selecciona opción [0-30]: " opcion

        case $opcion in
            1)  crear_backend ;;
            2)  eliminar_backend ;;
            3)  listar_backends ;;
            4)  renovar_backend ;;
            5)  editar_backend ;;
            6)  estado_backends ;;
            7)  ver_trafico ;;
            8)  ver_conexiones ;;
            9)  detalle_conexiones ;;
            10) monitor_realtime ;;
            11) verificar_online ;;
            12) cambiar_limite ;;
            13) resetear_trafico ;;
            14) limpiar_expirados ;;
            15) eliminar_todos ;;
            16) estado_nginx ;;
            17) ver_logs ;;
            18) gestionar_ips ;;
            19) info_servidor ;;
            20) reiniciar_monitor ;;
            21) hacer_backup ;;
            22) restaurar_backup ;;
            23) exportar_datos ;;
            24) trafico_global_vnstat ;;
            25) top_ips_consumidoras ;;
            26) historial_conexiones ;;
            27) regenerate_nginx && msg -verd "Nginx regenerado" ;;
            28) verificar_integridad ;;
            29) alertas_trafico ;;
            30) acerca_de ;;
            0)
                echo ""
                echo -e "  ${CIAN}Hasta luego! - Backend Manager Pro v6.0${SEMCOR}"
                echo ""
                exit 0
                ;;
            *)
                msg -verm "Opción inválida"
                ;;
        esac

        echo ""
        read -p "  Presiona ENTER para continuar..." _
    done
}

# ─── FUNCIÓN 24: TRÁFICO GLOBAL VNSTAT ───────────────────────────────────────
trafico_global_vnstat() {
    msg -tit "TRÁFICO GLOBAL DEL SERVIDOR (VNSTAT)"
    echo ""

    if ! command -v vnstat &>/dev/null; then
        msg -verm "vnstat no está instalado"
        echo -e "  ${AMARILLO}Instalando...${SEMCOR}"
        apt install -y vnstat > /dev/null 2>&1
        systemctl enable vnstat > /dev/null 2>&1
        systemctl start vnstat > /dev/null 2>&1
        msg -verd "vnstat instalado. Los datos estarán disponibles en unos minutos."
        return
    fi

    local iface=$(ip route | grep default | awk '{print $5}' | head -1)
    [ -z "$iface" ] && { msg -verm "No se detectó interfaz de red"; return; }

    echo -e "  ${BLANCO}Interfaz: ${CIAN}$iface${SEMCOR}"
    echo ""

    echo -e "  ${MORADO}═══ RESUMEN ═══${SEMCOR}"
    vnstat -i "$iface" -s 2>/dev/null | while read line; do
        echo -e "  ${GRIS}$line${SEMCOR}"
    done

    echo ""
    echo -e "  ${MORADO}═══ HOY ═══${SEMCOR}"
    vnstat -i "$iface" -d 1 2>/dev/null | while read line; do
        echo -e "  ${GRIS}$line${SEMCOR}"
    done

    echo ""
    echo -e "  ${MORADO}═══ ESTE MES ═══${SEMCOR}"
    vnstat -i "$iface" -m 1 2>/dev/null | while read line; do
        echo -e "  ${GRIS}$line${SEMCOR}"
    done

    echo ""
    echo -e "  ${MORADO}═══ TOP 10 DÍAS ═══${SEMCOR}"
    vnstat -i "$iface" -t 2>/dev/null | while read line; do
        echo -e "  ${GRIS}$line${SEMCOR}"
    done

    echo ""
    echo -e "  ${MORADO}═══ TRÁFICO POR HORA (HOY) ═══${SEMCOR}"
    vnstat -i "$iface" -h 2>/dev/null | while read line; do
        echo -e "  ${GRIS}$line${SEMCOR}"
    done
}

# ─── FUNCIÓN 25: TOP IPs CONSUMIDORAS ────────────────────────────────────────
top_ips_consumidoras() {
    msg -tit "TOP IPs CON MÁS CONEXIONES"
    echo ""

    echo -e "  ${BLANCO}[1]${SEMCOR} Top IPs globales (todas las conexiones)"
    echo -e "  ${BLANCO}[2]${SEMCOR} Top IPs por backend específico"
    echo -e "  ${BLANCO}[3]${SEMCOR} Top IPs desde logs de Nginx"
    echo -e "  ${BLANCO}[0]${SEMCOR} Volver"
    echo ""
    read -p "  Selecciona: " topt

    case $topt in
        1)
            echo ""
            echo -e "  ${BLANCO}Top 30 IPs con más conexiones activas:${SEMCOR}"
            msg -bar2
            printf "  ${BLANCO}%-8s %-20s %-30s${SEMCOR}\n" "CONEX" "IP" "BARRA"
            msg -bar2
            ss -tn state established 2>/dev/null | tail -n +2 | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -rn | head -30 | while read count ip; do
                local bar_len=$((count / 2))
                [ "$bar_len" -gt 40 ] && bar_len=40
                [ "$bar_len" -lt 1 ] && bar_len=1
                local bar=$(printf '█%.0s' $(seq 1 $bar_len 2>/dev/null))
                local color="${VERDE}"
                [ "$count" -ge 20 ] && color="${AMARILLO}"
                [ "$count" -ge 50 ] && color="${ROJO}"
                printf "  ${color}%-8s${SEMCOR} %-20s ${color}%s${SEMCOR}\n" "$count" "$ip" "$bar"
            done
            ;;
        2)
            if [ ! -s "$USER_DATA" ]; then
                msg -ama "No hay backends"
                return
            fi
            local i=1
            while IFS='|' read -r bname bip bport bexp blimit; do
                [ -z "$bname" ] && continue
                echo -e "  ${BLANCO}[$i]${SEMCOR} $bname (${bip}:${bport})"
                i=$((i+1))
            done < "$USER_DATA"
            echo ""
            read -p "  Selecciona: " bsel
            local btarget=$(sed -n "${bsel}p" "$USER_DATA")
            [ -z "$btarget" ] && { msg -verm "Inválido"; return; }
            local btip=$(echo "$btarget" | cut -d'|' -f2)
            local btport=$(echo "$btarget" | cut -d'|' -f3)
            local btname=$(echo "$btarget" | cut -d'|' -f1)

            echo ""
            echo -e "  ${BLANCO}Top IPs conectadas a $btname (${btip}:${btport}):${SEMCOR}"
            msg -bar2
            ss -tn state established "dst ${btip}:${btport}" 2>/dev/null | tail -n +2 | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -rn | head -20 | while read count ip; do
                local bar_len=$((count))
                [ "$bar_len" -gt 40 ] && bar_len=40
                [ "$bar_len" -lt 1 ] && bar_len=1
                local bar=$(printf '█%.0s' $(seq 1 $bar_len 2>/dev/null))
                printf "  ${CIAN}%-6s${SEMCOR} %-20s ${VERDE}%s${SEMCOR}\n" "$count" "$ip" "$bar"
            done
            ;;
        3)
            echo ""
            echo -e "  ${BLANCO}Top 30 IPs desde access.log de Nginx:${SEMCOR}"
            msg -bar2
            if [ -f /var/log/nginx/access.log ]; then
                awk '{print $1}' /var/log/nginx/access.log 2>/dev/null | sort | uniq -c | sort -rn | head -30 | while read count ip; do
                    printf "  ${CIAN}%-8s${SEMCOR} %s\n" "$count" "$ip"
                done
            else
                msg -ama "No se encontró access.log"
            fi
            ;;
        0|*) return ;;
    esac
}

# ─── FUNCIÓN 26: HISTORIAL DE CONEXIONES ─────────────────────────────────────
historial_conexiones() {
    msg -tit "HISTORIAL DE CONEXIONES (ÚLTIMAS 24H)"
    echo ""

    if [ ! -f "$CONNECTIONS_LOG" ] || [ ! -s "$CONNECTIONS_LOG" ]; then
        msg -ama "No hay datos de historial aún. El monitor recopila datos cada 30 segundos."
        return
    fi

    echo -e "  ${BLANCO}Conexiones registradas (últimas entradas):${SEMCOR}"
    msg -bar2
    printf "  ${BLANCO}%-22s %-12s %-30s${SEMCOR}\n" "FECHA/HORA" "CONEXIONES" "GRÁFICO"
    msg -bar2

    local max_conn=1
    while IFS='|' read -r ts conns; do
        [ -z "$ts" ] && continue
        [ "${conns:-0}" -gt "$max_conn" ] 2>/dev/null && max_conn=$conns
    done < "$CONNECTIONS_LOG"

    tail -60 "$CONNECTIONS_LOG" | while IFS='|' read -r ts conns; do
        [ -z "$ts" ] && continue
        local fecha=$(date -d @$ts '+%d/%m/%Y %H:%M:%S' 2>/dev/null || echo "$ts")
        local bar_len=1
        if [ "$max_conn" -gt 0 ] 2>/dev/null; then
            bar_len=$((conns * 30 / max_conn))
        fi
        [ "$bar_len" -lt 1 ] && bar_len=1
        [ "$bar_len" -gt 30 ] && bar_len=30
        local bar=$(printf '█%.0s' $(seq 1 $bar_len 2>/dev/null))
        local color="${VERDE}"
        [ "${conns:-0}" -ge 50 ] && color="${AMARILLO}"
        [ "${conns:-0}" -ge 100 ] && color="${ROJO}"
        printf "  %-22s ${color}%-12s %s${SEMCOR}\n" "$fecha" "$conns" "$bar"
    done

    local total_entries=$(wc -l < "$CONNECTIONS_LOG" 2>/dev/null)
    echo ""
    msg -bar2
    echo -e "  ${BLANCO}Entradas totales:${SEMCOR} $total_entries"
    echo -e "  ${BLANCO}Peak conexiones:${SEMCOR} $max_conn"
}

# ─── FUNCIÓN 28: VERIFICAR INTEGRIDAD ────────────────────────────────────────
verificar_integridad() {
    msg -tit "VERIFICAR INTEGRIDAD DEL SISTEMA"
    echo ""

    local errores=0

    # Verificar archivos
    echo -e "  ${BLANCO}Archivos del sistema:${SEMCOR}"
    for f in "$USER_DATA" "$TRAFFIC_DB" "$CONNECTIONS_LOG"; do
        if [ -f "$f" ]; then
            local size=$(du -h "$f" | cut -f1)
            echo -e "  ${VERDE}✔${SEMCOR} $f ($size)"
        else
            echo -e "  ${ROJO}✘${SEMCOR} $f - NO ENCONTRADO"
            touch "$f" 2>/dev/null
            echo -e "    ${AMARILLO}→ Creado${SEMCOR}"
            errores=$((errores+1))
        fi
    done

    echo ""
    echo -e "  ${BLANCO}Servicios:${SEMCOR}"

    # Nginx
    if systemctl is-active --quiet nginx; then
        echo -e "  ${VERDE}✔${SEMCOR} Nginx: activo"
    else
        echo -e "  ${ROJO}✘${SEMCOR} Nginx: inactivo"
        errores=$((errores+1))
    fi

    # Monitor
    if systemctl is-active --quiet backend-monitor; then
        echo -e "  ${VERDE}✔${SEMCOR} Monitor de tráfico: activo"
    else
        echo -e "  ${ROJO}✘${SEMCOR} Monitor de tráfico: inactivo"
        errores=$((errores+1))
        echo -e "    ${AMARILLO}→ Intentando iniciar...${SEMCOR}"
        systemctl start backend-monitor 2>/dev/null
        if systemctl is-active --quiet backend-monitor; then
            echo -e "    ${VERDE}→ Iniciado correctamente${SEMCOR}"
        else
            echo -e "    ${ROJO}→ No se pudo iniciar${SEMCOR}"
        fi
    fi

    # vnstat
    if command -v vnstat &>/dev/null; then
        echo -e "  ${VERDE}✔${SEMCOR} vnstat: instalado"
    else
        echo -e "  ${ROJO}✘${SEMCOR} vnstat: no instalado"
        errores=$((errores+1))
    fi

    echo ""
    echo -e "  ${BLANCO}Configuración Nginx:${SEMCOR}"
    if nginx -t > /dev/null 2>&1; then
        echo -e "  ${VERDE}✔${SEMCOR} Configuración válida"
    else
        echo -e "  ${ROJO}✘${SEMCOR} Configuración con errores"
        nginx -t 2>&1 | while read line; do
            echo -e "    ${ROJO}$line${SEMCOR}"
        done
        errores=$((errores+1))
    fi

    # Verificar cadenas iptables
    echo ""
    echo -e "  ${BLANCO}Cadenas iptables de tráfico:${SEMCOR}"
    local chains_ok=0 chains_miss=0
    if [ -s "$USER_DATA" ]; then
        while IFS='|' read -r bname bip bport bexp blimit; do
            [ -z "$bname" ] && continue
            local CHAIN="TRAFFIC_${bname}"
            if iptables -L "$CHAIN" -n > /dev/null 2>&1; then
                echo -e "  ${VERDE}✔${SEMCOR} $CHAIN"
                chains_ok=$((chains_ok+1))
            else
                echo -e "  ${ROJO}✘${SEMCOR} $CHAIN - NO EXISTE"
                chains_miss=$((chains_miss+1))
                errores=$((errores+1))

                # Intentar recrear
                echo -e "    ${AMARILLO}→ Recreando cadena...${SEMCOR}"
                iptables -N "$CHAIN" 2>/dev/null
                iptables -A "$CHAIN" -d "$bip" -j RETURN 2>/dev/null
                iptables -A "$CHAIN" -s "$bip" -j RETURN 2>/dev/null
                iptables -I FORWARD -d "$bip" -j "$CHAIN" 2>/dev/null
                iptables -I FORWARD -s "$bip" -j "$CHAIN" 2>/dev/null
                iptables -I OUTPUT -d "$bip" -j "$CHAIN" 2>/dev/null
                iptables -I INPUT -s "$bip" -j "$CHAIN" 2>/dev/null
                echo -e "    ${VERDE}→ Cadena recreada${SEMCOR}"
            fi
        done < "$USER_DATA"
    fi

    # Verificar directorio de backups
    echo ""
    echo -e "  ${BLANCO}Directorio de backups:${SEMCOR}"
    if [ -d "$BACKUP_DIR" ]; then
        local bk_count=$(ls -1 ${BACKUP_DIR}/*.tar.gz 2>/dev/null | wc -l)
        echo -e "  ${VERDE}✔${SEMCOR} $BACKUP_DIR ($bk_count backups)"
    else
        echo -e "  ${ROJO}✘${SEMCOR} $BACKUP_DIR - NO EXISTE"
        mkdir -p "$BACKUP_DIR"
        echo -e "    ${AMARILLO}→ Creado${SEMCOR}"
        errores=$((errores+1))
    fi

    # Verificar consistencia users.db vs traffic.db
    echo ""
    echo -e "  ${BLANCO}Consistencia de datos:${SEMCOR}"
    if [ -s "$USER_DATA" ]; then
        local users_count=$(wc -l < "$USER_DATA")
        local traffic_count=$(wc -l < "$TRAFFIC_DB" 2>/dev/null || echo 0)

        while IFS='|' read -r bname bip bport bexp blimit; do
            [ -z "$bname" ] && continue
            if ! grep -q "^${bname}|" "$TRAFFIC_DB" 2>/dev/null; then
                echo -e "  ${AMARILLO}⚠${SEMCOR} $bname sin entrada en traffic.db - Creando..."
                echo "${bname}|0|0|0|$(date +%s)" >> "$TRAFFIC_DB"
            fi
        done < "$USER_DATA"
        echo -e "  ${VERDE}✔${SEMCOR} Backends: $users_count | Entradas tráfico: $traffic_count"
    fi

    echo ""
    msg -bar2
    if [ "$errores" -eq 0 ]; then
        echo -e "  ${VERDE}${NEGRITO}✔ Sistema íntegro - 0 errores encontrados${SEMCOR}"
    else
        echo -e "  ${AMARILLO}${NEGRITO}⚠ Se encontraron $errores problemas (se intentaron reparar)${SEMCOR}"
    fi
    msg -bar
}

# ─── FUNCIÓN 29: ALERTAS DE TRÁFICO EXCEDIDO ─────────────────────────────────
alertas_trafico() {
    msg -tit "ALERTAS DE TRÁFICO Y EXPIRACIÓN"
    echo ""

    if [ ! -s "$USER_DATA" ]; then
        msg -ama "No hay backends registrados"
        return
    fi

    local now=$(date +%s)
    local alertas=0

    echo -e "  ${BLANCO}${NEGRITO}═══ ALERTAS DE TRÁFICO ═══${SEMCOR}"
    echo ""

    while IFS='|' read -r bname bip bport bexp blimit; do
        [ -z "$bname" ] && continue

        local CHAIN="TRAFFIC_${bname}"
        local bytes=$(iptables -L "$CHAIN" -n -v -x 2>/dev/null | awk '/RETURN/ {sum+=$2} END{print sum+0}')
        [ -z "$bytes" ] && bytes=0

        # Alerta de tráfico
        if [ -n "$blimit" ] && [ "${blimit:-0}" -gt 0 ] 2>/dev/null; then
            local pct=$((bytes * 100 / blimit))

            if [ "$pct" -ge 100 ]; then
                echo -e "  ${ROJO}🚨 CRÍTICO${SEMCOR} $bname - Tráfico EXCEDIDO: $(format_bytes $bytes) / $(format_bytes $blimit) (${pct}%)"
                alertas=$((alertas+1))
            elif [ "$pct" -ge 90 ]; then
                echo -e "  ${ROJO}⚠ ALTO${SEMCOR}    $bname - Tráfico al ${pct}%: $(format_bytes $bytes) / $(format_bytes $blimit)"
                alertas=$((alertas+1))
            elif [ "$pct" -ge 75 ]; then
                echo -e "  ${AMARILLO}⚠ MEDIO${SEMCOR}   $bname - Tráfico al ${pct}%: $(format_bytes $bytes) / $(format_bytes $blimit)"
                alertas=$((alertas+1))
            fi
        fi

        # Alerta de expiración
        if [ -n "$bexp" ] && [ "$bexp" -gt 0 ] 2>/dev/null; then
            local diff=$((bexp - now))
            if [ "$diff" -le 0 ]; then
                echo -e "  ${ROJO}🚨 EXPIRADO${SEMCOR} $bname - Expiró el $(date -d @$bexp '+%d/%m/%Y %H:%M')"
                alertas=$((alertas+1))
            elif [ "$diff" -le 86400 ]; then
                echo -e "  ${ROJO}⚠ URGENTE${SEMCOR}  $bname - Expira en $(format_time_remaining $bexp)"
                alertas=$((alertas+1))
            elif [ "$diff" -le 259200 ]; then
                echo -e "  ${AMARILLO}⚠ PRONTO${SEMCOR}   $bname - Expira en $(format_time_remaining $bexp)"
                alertas=$((alertas+1))
            fi
        fi

        # Alerta de conexiones altas
        local conns=$(ss -tn state established "dst ${bip}:${bport}" 2>/dev/null | tail -n +2 | wc -l)
        if [ "${conns:-0}" -ge 100 ] 2>/dev/null; then
            echo -e "  ${AMARILLO}⚠ CONEX${SEMCOR}    $bname - ${conns} conexiones activas (alto)"
            alertas=$((alertas+1))
        fi

        # Alerta offline
        if ! timeout 2 bash -c "echo >/dev/tcp/$bip/$bport" 2>/dev/null; then
            echo -e "  ${ROJO}🔴 OFFLINE${SEMCOR}  $bname - No responde en ${bip}:${bport}"
            alertas=$((alertas+1))
        fi

    done < "$USER_DATA"

    echo ""
    msg -bar2
    if [ "$alertas" -eq 0 ]; then
        echo -e "  ${VERDE}${NEGRITO}✔ Sin alertas - Todo funcionando correctamente${SEMCOR}"
    else
        echo -e "  ${AMARILLO}${NEGRITO}⚠ Total de alertas: $alertas${SEMCOR}"
    fi

    echo ""
    echo -e "  ${BLANCO}Opciones:${SEMCOR}"
    echo -e "  ${BLANCO}[1]${SEMCOR} Limpiar backends expirados automáticamente"
    echo -e "  ${BLANCO}[2]${SEMCOR} Bloquear backends con tráfico excedido"
    echo -e "  ${BLANCO}[0]${SEMCOR} Volver"
    echo ""
    read -p "  Selecciona: " aopt

    case $aopt in
        1) limpiar_expirados ;;
        2)
            echo ""
            while IFS='|' read -r bname bip bport bexp blimit; do
                [ -z "$bname" ] && continue
                if [ -n "$blimit" ] && [ "${blimit:-0}" -gt 0 ] 2>/dev/null; then
                    local CHAIN="TRAFFIC_${bname}"
                    local bytes=$(iptables -L "$CHAIN" -n -v -x 2>/dev/null | awk '/RETURN/ {sum+=$2} END{print sum+0}')
                    local pct=$((${bytes:-0} * 100 / blimit))
                    if [ "$pct" -ge 100 ]; then
                        iptables -I FORWARD -d "$bip" -j DROP 2>/dev/null
                        iptables -I FORWARD -s "$bip" -j DROP 2>/dev/null
                        msg -verd "Bloqueado: $bname (tráfico excedido: ${pct}%)"
                    fi
                fi
            done < "$USER_DATA"
            ;;
        0|*) return ;;
    esac
}

# ─── FUNCIÓN 30: ACERCA DE ───────────────────────────────────────────────────
acerca_de() {
    clear
    echo -e "${CIAN}"
    echo "  ╔══════════════════════════════════════════════════════════╗"
    echo "  ║                                                          ║"
    echo "  ║          BACKEND MANAGER PRO v6.0                        ║"
    echo "  ║                                                          ║"
    echo "  ║          Desarrollado por: JOHNNY                        ║"
    echo "  ║          Telegram: @Jrcelulares                          ║"
    echo "  ║                                                          ║"
    echo "  ╠══════════════════════════════════════════════════════════╣"
    echo "  ║                                                          ║"
    echo "  ║  Características:                                        ║"
    echo "  ║  • 30 opciones de administración                         ║"
    echo "  ║  • Monitoreo de tráfico en tiempo real (GB/TB)           ║"
    echo "  ║  • Conteo de conexiones por backend                      ║"
    echo "  ║  • Sistema de alertas automáticas                        ║"
    echo "  ║  • Gestión de IPs (bloqueo/desbloqueo)                   ║"
    echo "  ║  • Backup y restauración                                 ║"
    echo "  ║  • Exportación de datos (TXT/CSV)                        ║"
    echo "  ║  • Monitor daemon con systemd                            ║"
    echo "  ║  • Integración con vnstat e iptables                     ║"
    echo "  ║  • Verificación de integridad                            ║"
    echo "  ║                                                          ║"
    echo "  ╠══════════════════════════════════════════════════════════╣"
    echo "  ║                                                          ║"
    echo "  ║  Archivos del sistema:                                   ║"
    echo "  ║  • /etc/backendmanager/users.db                          ║"
    echo "  ║  • /etc/backendmanager/traffic.db                        ║"
    echo "  ║  • /etc/backendmanager/connections.log                   ║"
    echo "  ║  • /etc/backendmanager/traffic_monitor.sh                ║"
    echo "  ║  • /root/backendmanager.sh                               ║"
    echo "  ║                                                          ║"
    echo "  ╚══════════════════════════════════════════════════════════╝"
    echo -e "${SEMCOR}"

    echo ""
    echo -e "  ${BLANCO}Versión instalada:${SEMCOR} 6.0"
    echo -e "  ${BLANCO}Fecha de instalación:${SEMCOR} $(stat -c %y /root/backendmanager.sh 2>/dev/null | cut -d. -f1)"
    echo -e "  ${BLANCO}Backends activos:${SEMCOR} $(wc -l < "$USER_DATA" 2>/dev/null || echo 0)"
}

# ============================================================
# ARRANQUE
# ============================================================
check_nginx
menu_principal
MAINSCRIPT

# ============================================================
# FIN DEL SCRIPT PRINCIPAL - VOLVER AL INSTALADOR
# ============================================================

chmod +x /root/backendmanager.sh

echo -e "${VERDE}[✓] Script principal generado: /root/backendmanager.sh${SEMCOR}"

# ─── CREAR ALIAS PARA ACCESO RÁPIDO ──────────────────────────────────────────
SHELL_RC=""
if [ -f /root/.bashrc ]; then
    SHELL_RC="/root/.bashrc"
elif [ -f /root/.zshrc ]; then
    SHELL_RC="/root/.zshrc"
fi

if [ -n "$SHELL_RC" ]; then
    # Eliminar alias anteriores
    sed -i '/alias bkm=/d' "$SHELL_RC" 2>/dev/null
    sed -i '/alias backendmanager=/d' "$SHELL_RC" 2>/dev/null
    sed -i '/alias backend=/d' "$SHELL_RC" 2>/dev/null

    # Agregar nuevos alias
    echo 'alias bkm="bash /root/backendmanager.sh"' >> "$SHELL_RC"
    echo 'alias backendmanager="bash /root/backendmanager.sh"' >> "$SHELL_RC"
    echo 'alias backend="bash /root/backendmanager.sh"' >> "$SHELL_RC"

    source "$SHELL_RC" 2>/dev/null
    echo -e "${VERDE}[✓] Alias creados: bkm, backendmanager, backend${SEMCOR}"
fi

# ─── CREAR ENLACE SIMBÓLICO EN /usr/local/bin ─────────────────────────────────
ln -sf /root/backendmanager.sh /usr/local/bin/bkm 2>/dev/null
chmod +x /usr/local/bin/bkm 2>/dev/null
echo -e "${VERDE}[✓] Comando global 'bkm' disponible${SEMCOR}"

# ─── CREAR CRON PARA LIMPIEZA AUTOMÁTICA DE EXPIRADOS ─────────────────────────
CRON_JOB="0 */6 * * * /bin/bash -c 'source /root/backendmanager.sh --auto-clean' > /dev/null 2>&1"

# Script de limpieza automática
cat > /etc/backendmanager/auto_clean.sh << 'CLEANEOF'
#!/bin/bash
USER_DATA="/etc/backendmanager/users.db"
TRAFFIC_DB="/etc/backendmanager/traffic.db"
BACKEND_CONF="/etc/nginx/sites-available/backendmanager"
BACKEND_ENABLED="/etc/nginx/sites-enabled/backendmanager"
LOG="/etc/backendmanager/logs/auto_clean.log"

now=$(date +%s)
cleaned=0

[ ! -s "$USER_DATA" ] && exit 0

tmp_file="/tmp/users_autoclean_$$"

while IFS='|' read -r bname bip bport bexp blimit; do
    [ -z "$bname" ] && continue

    remove=false

    # Verificar expiración
    if [ -n "$bexp" ] && [ "$bexp" -gt 0 ] 2>/dev/null; then
        if [ "$now" -ge "$bexp" ]; then
            remove=true
        fi
    fi

    # Verificar tráfico excedido
    if [ -n "$blimit" ] && [ "${blimit:-0}" -gt 0 ] 2>/dev/null; then
        CHAIN="TRAFFIC_${bname}"
        bytes=$(iptables -L "$CHAIN" -n -v -x 2>/dev/null | awk '/RETURN/ {sum+=$2} END{print sum+0}')
        if [ "${bytes:-0}" -ge "$blimit" ] 2>/dev/null; then
            # Bloquear en vez de eliminar
            iptables -I FORWARD -d "$bip" -j DROP 2>/dev/null
            iptables -I FORWARD -s "$bip" -j DROP 2>/dev/null
            echo "$(date): BLOQUEADO $bname - tráfico excedido (${bytes}/${blimit})" >> "$LOG"
        fi
    fi

    if [ "$remove" = true ]; then
        # Limpiar iptables
        CHAIN="TRAFFIC_${bname}"
        iptables -D FORWARD -d "$bip" -j "$CHAIN" 2>/dev/null
        iptables -D FORWARD -s "$bip" -j "$CHAIN" 2>/dev/null
        iptables -D OUTPUT -d "$bip" -j "$CHAIN" 2>/dev/null
        iptables -D INPUT -s "$bip" -j "$CHAIN" 2>/dev/null
        iptables -F "$CHAIN" 2>/dev/null
        iptables -X "$CHAIN" 2>/dev/null
        sed -i "/^${bname}|/d" "$TRAFFIC_DB" 2>/dev/null
        rm -f /var/log/nginx/backend_${bname}_*.log 2>/dev/null
        echo "$(date): ELIMINADO $bname - expirado" >> "$LOG"
        cleaned=$((cleaned+1))
    else
        echo "${bname}|${bip}|${bport}|${bexp}|${blimit}" >> "$tmp_file"
    fi
done < "$USER_DATA"

if [ -f "$tmp_file" ]; then
    mv "$tmp_file" "$USER_DATA"
else
    > "$USER_DATA"
fi

# Regenerar nginx si hubo cambios
if [ "$cleaned" -gt 0 ]; then
    # Regenerar configuración nginx simplificada
    > "$BACKEND_CONF"
    while IFS='|' read -r bname bip bport bexp blimit; do
        [ -z "$bname" ] && continue
        cat >> "$BACKEND_CONF" << NGXBLOCK
upstream backend_${bname} {
    server ${bip}:${bport};
    keepalive 32;
}
server {
    listen 80;
    server_name ${bname}.backend.local;
    location / {
        proxy_pass http://backend_${bname};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
NGXBLOCK
    done < "$USER_DATA"
    ln -sf "$BACKEND_CONF" "$BACKEND_ENABLED" 2>/dev/null
    nginx -t > /dev/null 2>&1 && systemctl reload nginx
    echo "$(date): Nginx regenerado - $cleaned backends eliminados" >> "$LOG"
fi
CLEANEOF

chmod +x /etc/backendmanager/auto_clean.sh

# Agregar al cron
(crontab -l 2>/dev/null | grep -v "auto_clean.sh"; echo "0 */6 * * * /bin/bash /etc/backendmanager/auto_clean.sh > /dev/null 2>&1") | crontab -
echo -e "${VERDE}[✓] Limpieza automática programada (cada 6 horas)${SEMCOR}"

# ─── CREAR SCRIPT DE DESINSTALACIÓN ──────────────────────────────────────────
cat > /root/uninstall_backendmanager.sh << 'UNINSTEOF'
#!/bin/bash
echo "═══════════════════════════════════════════"
echo "  Desinstalar Backend Manager Pro v6.0"
echo "═══════════════════════════════════════════"
echo ""
read -p "¿Confirmar desinstalación completa? [s/N]: " confirm
[[ ! "$confirm" =~ ^[sS]$ ]] && exit 0

echo "[*] Deteniendo servicios..."
systemctl stop backend-monitor 2>/dev/null
systemctl disable backend-monitor 2>/dev/null
rm -f /etc/systemd/system/backend-monitor.service
systemctl daemon-reload

echo "[*] Eliminando archivos..."
rm -rf /etc/backendmanager
rm -f /root/backendmanager.sh
rm -f /usr/local/bin/bkm
rm -f /etc/nginx/sites-available/backendmanager
rm -f /etc/nginx/sites-enabled/backendmanager
rm -f /etc/nginx/conf.d/backend_log.conf

echo "[*] Limpiando iptables..."
for chain in $(iptables -L -n | grep "Chain TRAFFIC_" | awk '{print $2}'); do
    iptables -F "$chain" 2>/dev/null
    iptables -X "$chain" 2>/dev/null
done

echo "[*] Limpiando cron..."
(crontab -l 2>/dev/null | grep -v "auto_clean.sh") | crontab -

echo "[*] Limpiando alias..."
sed -i '/alias bkm=/d' /root/.bashrc 2>/dev/null
sed -i '/alias backendmanager=/d' /root/.bashrc 2>/dev/null
sed -i '/alias backend=/d' /root/.bashrc 2>/dev/null

nginx -t > /dev/null 2>&1 && systemctl reload nginx

echo ""
echo "[✓] Backend Manager Pro desinstalado completamente"
echo "[i] Los backups se conservan en: /root/backendmanager_backups/"
rm -f /root/uninstall_backendmanager.sh
UNINSTEOF

chmod +x /root/uninstall_backendmanager.sh
echo -e "${VERDE}[✓] Script de desinstalación: /root/uninstall_backendmanager.sh${SEMCOR}"

# ─── VERIFICACIÓN FINAL ──────────────────────────────────────────────────────
echo ""
echo -e "${CIAN}════════════════════════════════════════════════════════════${SEMCOR}"
echo -e "${VERDE}${NEGRITO}"
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║                                                          ║"
echo "  ║     ✔ INSTALACIÓN COMPLETADA EXITOSAMENTE               ║"
echo "  ║                                                          ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo -e "${SEMCOR}"

echo -e "  ${BLANCO}Archivos instalados:${SEMCOR}"
echo -e "  ${VERDE}✔${SEMCOR} /root/backendmanager.sh          ${GRIS}(Script principal)${SEMCOR}"
echo -e "  ${VERDE}✔${SEMCOR} /etc/backendmanager/             ${GRIS}(Directorio de datos)${SEMCOR}"
echo -e "  ${VERDE}✔${SEMCOR} /etc/backendmanager/users.db     ${GRIS}(Base de datos)${SEMCOR}"
echo -e "  ${VERDE}✔${SEMCOR} /etc/backendmanager/traffic.db   ${GRIS}(Datos de tráfico)${SEMCOR}"
echo -e "  ${VERDE}✔${SEMCOR} /etc/backendmanager/auto_clean.sh ${GRIS}(Limpieza automática)${SEMCOR}"
echo -e "  ${VERDE}✔${SEMCOR} /usr/local/bin/bkm               ${GRIS}(Comando global)${SEMCOR}"
echo ""
echo -e "  ${BLANCO}Servicios activos:${SEMCOR}"

if systemctl is-active --quiet nginx; then
    echo -e "  ${VERDE}✔${SEMCOR} Nginx: activo"
else
    echo -e "  ${ROJO}✘${SEMCOR} Nginx: inactivo"
fi

if systemctl is-active --quiet backend-monitor; then
    echo -e "  ${VERDE}✔${SEMCOR} Monitor de tráfico: activo"
else
    echo -e "  ${ROJO}✘${SEMCOR} Monitor de tráfico: inactivo"
fi

echo ""
echo -e "  ${BLANCO}Cómo ejecutar:${SEMCOR}"
echo -e "  ${CIAN}  bash /root/backendmanager.sh${SEMCOR}"
echo -e "  ${CIAN}  bkm${SEMCOR}"
echo -e "  ${CIAN}  backendmanager${SEMCOR}"
echo -e "  ${CIAN}  backend${SEMCOR}"
echo ""
echo -e "  ${BLANCO}Desinstalar:${SEMCOR}"
echo -e "  ${CIAN}  bash /root/uninstall_backendmanager.sh${SEMCOR}"
echo ""
echo -e "${CIAN}════════════════════════════════════════════════════════════${SEMCOR}"
echo ""

# ─── PREGUNTAR SI EJECUTAR AHORA ─────────────────────────────────────────────
read -p "  ¿Ejecutar Backend Manager ahora? [S/n]: " run_now
if [[ ! "$run_now" =~ ^[nN]$ ]]; then
    bash /root/backendmanager.sh
fi
