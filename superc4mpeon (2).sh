#!/bin/bash
# ============================================================
# Instalador del Backend Manager by JOHNNY (@Jrcelulares)
# Versión: 4.83 - Con panel visual mejorado y menú profesional
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
echo -e "\E[41;1;37m       INSTALADOR BACKEND MANAGER by JOHNNY (@Jrcelulares)     \E[0m"
echo -e "${CIAN}════════════════════════════════════════════════════════${SEMCOR}"

# Confirmar sobrescritura si existe
if [ -f /root/superc4mpeon.sh ]; then
    echo -e "${AMARILLO}[!] Ya existe /root/superc4mpeon.sh${SEMCOR}"
    read -p "¿Deseas sobrescribirlo? (s/n): " resp
    if [[ ! "$resp" =~ ^[sS]$ ]]; then
        echo -e "${ROJO}Instalación cancelada.${SEMCOR}"
        exit 1
    fi
fi

# Actualizar e instalar dependencias
echo -e "${AMARILLO}[ℹ] Instalando dependencias...${SEMCOR}"
apt update -y
apt install -y nginx curl wget speedtest-cli ufw bc net-tools

# Crear directorios y archivos de configuración
mkdir -p /etc/nginx/superc4mpeon_backups
touch /etc/nginx/superc4mpeon_users.txt
mkdir -p /root/superc4mpeon_backups

# Crear script principal en /root/superc4mpeon.sh
cat > /root/superc4mpeon.sh << 'EOF'
#!/bin/bash
# ============================================================
# BACKEND MANAGER by JOHNNY (@Jrcelulares) v4.83
# Con panel visual mejorado y menú profesional
# ============================================================

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

# ARCHIVOS DE CONFIGURACIÓN
BACKEND_CONF="/etc/nginx/sites-available/superc4mpeon"
BACKEND_ENABLED="/etc/nginx/sites-enabled/superc4mpeon"
USER_DATA="/etc/nginx/superc4mpeon_users.txt"
BACKUP_DIR="/root/superc4mpeon_backups"

# ============ FUNCIÓN DE MENSAJES ============
msg() {
    case $1 in
        -tit) echo -e "${MORADO}════════════════════════════════════════════════════════${SEMCOR}"
              echo -e "${BLANCO}${NEGRITO}    $2${SEMCOR}"
              echo -e "${MORADO}════════════════════════════════════════════════════════${SEMCOR}" ;;
        -bar) echo -e "${CIAN}════════════════════════════════════════════════════════${SEMCOR}" ;;
        -verd) echo -e "${VERDE}[✓] $2${SEMCOR}" ;;
        -verm) echo -e "${ROJO}[✗] $2${SEMCOR}" ;;
        -ama) echo -e "${AMARILLO}[!] $2${SEMCOR}" ;;
        -info) echo -e "${CIAN}[ℹ] $2${SEMCOR}" ;;
        *) echo -e "$1" ;;
    esac
}

# ============ FORMATO DE BYTES ============
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

# ============ OBTENER DOMINIOS MADRE ACTIVOS ============
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

# ============ CONTAR BACKENDS ============
count_backends() {
    if [ -f "$USER_DATA" ]; then
        wc -l < "$USER_DATA" 2>/dev/null || echo 0
    else
        echo 0
    fi
}

# ============ OBTENER ÚLTIMO BACKUP ============
last_backup() {
    local latest=$(ls -t "$BACKUP_DIR"/backends_*.tar.gz 2>/dev/null | head -1)
    if [ -n "$latest" ]; then
        local fecha=$(stat -c '%y' "$latest" 2>/dev/null | cut -d. -f1 | cut -d' ' -f1,2)
        echo "SI ($fecha)"
    else
        echo "NO"
    fi
}

# ============ FUNCIÓN PARA DIBUJAR BARRA DE PROGRESO ============
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

# ============ PANEL DE ESTADO SUPERIOR MEJORADO ============
show_status_panel() {
    clear
    
    # Título principal personalizado
    echo -e "${TURQUESA}════════════════════════════════════════════════════════${SEMCOR}"
    echo -e "\E[41;1;37m      🔥 BACKEND MANAGER by JOHNNY (@Jrcelulares) 🔥     \E[0m"
    echo -e "${TURQUESA}════════════════════════════════════════════════════════${SEMCOR}"
    
    # Fecha, hora e IP
    local fecha=$(date '+%d/%m/%Y %H:%M:%S')
    local ip=$(curl -s ifconfig.me 2>/dev/null || echo "No disponible")
    echo -e "${CIAN}📅 FECHA:${SEMCOR} $fecha     ${CIAN}🌐 IP:${SEMCOR} $ip"
    echo -e "${CIAN}════════════════════════════════════════════════════════${SEMCOR}"
    
    # Nginx, dominios, backends
    local nginx_status=$(systemctl is-active nginx)
    if [ "$nginx_status" = "active" ]; then
        nginx_status="${VERDE}✅ ACTIVO${SEMCOR}"
    else
        nginx_status="${ROJO}❌ INACTIVO${SEMCOR}"
    fi
    
    # Obtener dominios reales
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
    
    # Dominio madre activo y lista
    echo -e "📌 Dominio madre: ${VERDE}$first_domain${SEMCOR}     ${CIAN}📋 Lista:${SEMCOR} $domain_list"
    
    # Header, tráfico, scanner
    echo -e "🔹 Header: Backend     🔹 Tráfico: ON     🔹 Scanner: ON (30s)"
    
    # Backup
    echo -e "💾 Backup: $(last_backup)"
    echo -e "${CIAN}════════════════════════════════════════════════════════${SEMCOR}"
    
    # DISCO
    local disk_total=$(df -BG / | awk 'NR==2 {print $2}' | sed 's/G//')
    local disk_used=$(df -BG / | awk 'NR==2 {print $3}' | sed 's/G//')
    local disk_percent=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    local disk_bar=$(draw_bar $disk_percent)
    echo -e "💾 DISCO: [$disk_bar] ${disk_used}GB / ${disk_total}GB (${disk_percent}%)"
    
    # RAM
    local mem_line=$(free -m | grep Mem:)
    local mem_total=$(echo $mem_line | awk '{print $2}')
    local mem_used=$(echo $mem_line | awk '{print $3}')
    local mem_percent=$((mem_used * 100 / mem_total))
    local mem_bar=$(draw_bar $mem_percent)
    echo -e "🧠 RAM:   [$mem_bar] ${mem_used}MB / ${mem_total}MB (${mem_percent}%)"
    
    # CPU
    local cpu_cores=$(nproc)
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    if [ -z "$cpu_usage" ]; then cpu_usage=0; fi
    local cpu_percent=$(printf "%.0f" "$cpu_usage" 2>/dev/null || echo 0)
    local cpu_bar=$(draw_bar $cpu_percent)
    local load=$(uptime | awk -F'load average:' '{print $2}' | xargs)
    echo -e "⚡ CPU:   [$cpu_bar] ${cpu_usage}% (load $load)"
    
    # RED desde boot
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

# ============ FUNCIONES DEL MENÚ ============
# (Aquí van todas las funciones, que no cambian)
# 1) Dominios madre (crear/editar/eliminar)
manage_domains() {
    show_status_panel
    echo -e "${AMARILLO}GESTIÓN DE DOMINIOS MADRE${SEMCOR}"
    echo "1) Crear nuevo dominio"
    echo "2) Editar dominio existente"
    echo "3) Eliminar dominio"
    echo "4) Volver"
    read -p "Opción: " opt
    case $opt in
        1)
            read -p "Nombre del dominio (ej: midominio.com): " domain
            if [ -z "$domain" ]; then
                msg -verm "Dominio no válido"
            else
                cat > "/etc/nginx/sites-available/$domain" <<INNER
server {
    listen 80;
    server_name $domain;
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
INNER
                ln -s "/etc/nginx/sites-available/$domain" "/etc/nginx/sites-enabled/$domain" 2>/dev/null
                systemctl reload nginx
                msg -verd "Dominio $domain creado"
            fi
            ;;
        2)
            read -p "Dominio a editar: " domain
            if [ -f "/etc/nginx/sites-available/$domain" ]; then
                nano "/etc/nginx/sites-available/$domain"
                systemctl reload nginx
            else
                msg -verm "No existe"
            fi
            ;;
        3)
            read -p "Dominio a eliminar: " domain
            rm -f "/etc/nginx/sites-available/$domain" "/etc/nginx/sites-enabled/$domain"
            systemctl reload nginx
            msg -verd "Eliminado"
            ;;
        4) return ;;
        *) msg -verm "Opción inválida" ;;
    esac
    read -p "Presiona ENTER..."
}

# 2) Agregar backend (nombre + IP + puerto)
add_backend() {
    show_status_panel
    echo -e "${AMARILLO}AGREGAR BACKEND${SEMCOR}"
    read -p "Nombre: " name
    read -p "IP: " ip
    read -p "Puerto (80): " port
    port=${port:-80}
    read -p "Días de expiración (0 = sin expiración): " days
    if [ ! -f "$USER_DATA" ]; then touch "$USER_DATA"; fi
    if [ $days -gt 0 ]; then
        exp=$(( $(date +%s) + (days * 86400) ))
    else
        exp=0
    fi
    echo "$name:$ip:$port:$exp" >> "$USER_DATA"
    msg -verd "Backend agregado"
    read -p "Presiona ENTER..."
}

# 3) Listar backends
list_backends() {
    show_status_panel
    echo -e "${AMARILLO}LISTA DE BACKENDS${SEMCOR}"
    if [ -f "$USER_DATA" ]; then
        column -t -s: "$USER_DATA" | while read line; do
            echo -e "${VERDE}$line${SEMCOR}"
        done
    else
        msg -ama "No hay backends"
    fi
    read -p "Presiona ENTER..."
}

# 4) Listar dominios madre
list_domains() {
    show_status_panel
    echo -e "${AMARILLO}DOMINIOS MADRE ACTIVOS${SEMCOR}"
    for file in /etc/nginx/sites-enabled/*; do
        if [ -f "$file" ] && [ "$(basename "$file")" != "default" ]; then
            domain=$(grep server_name "$file" | head -1 | awk '{print $2}' | tr -d ';')
            echo -e "${VERDE}$(basename "$file")${SEMCOR} → $domain"
        fi
    done
    read -p "Presiona ENTER..."
}

# 5) Eliminar backend
delete_backend() {
    show_status_panel
    echo -e "${AMARILLO}ELIMINAR BACKEND${SEMCOR}"
    read -p "Nombre del backend: " name
    if [ -f "$USER_DATA" ]; then
        grep -v "^$name:" "$USER_DATA" > /tmp/users.tmp
        mv /tmp/users.tmp "$USER_DATA"
        msg -verd "Eliminado"
    else
        msg -verm "No existe"
    fi
    read -p "Presiona ENTER..."
}

# 6) Healthcheck (HTTP y latencia)
healthcheck() {
    show_status_panel
    echo -e "${AMARILLO}HEALTHCHECK DE BACKENDS${SEMCOR}"
    if [ -f "$USER_DATA" ]; then
        while IFS=: read -r name ip port exp; do
            echo -n "Probando $name ($ip:$port)... "
            if curl -s --connect-timeout 2 "http://$ip:$port" >/dev/null; then
                lat=$(curl -o /dev/null -s -w '%{time_total}' "http://$ip:$port" 2>/dev/null)
                echo -e "${VERDE}OK (${lat}s)${SEMCOR}"
            else
                echo -e "${ROJO}FALLÓ${SEMCOR}"
            fi
        done < "$USER_DATA"
    else
        msg -ama "No hay backends"
    fi
    read -p "Presiona ENTER..."
}

# 7) Validar conexión (dominio + backend por header)
validate_connection() {
    show_status_panel
    echo -e "${AMARILLO}VALIDAR CONEXIÓN CON HEADER${SEMCOR}"
    read -p "Dominio madre: " domain
    read -p "Backend (nombre o IP:puerto): " backend
    if [[ $backend =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$ ]]; then
        target=$backend
    else
        line=$(grep "^$backend:" "$USER_DATA" 2>/dev/null)
        if [ -n "$line" ]; then
            ip=$(echo $line | cut -d: -f2)
            port=$(echo $line | cut -d: -f3)
            target="$ip:$port"
        else
            target="$backend"
        fi
    fi
    curl -H "Backend: $target" -H "Host: $domain" http://127.0.0.1 -v 2>&1 | grep -E "< HTTP/|< Location|Connected to"
    read -p "Presiona ENTER..."
}

# 8) Editar timeouts del dominio madre
edit_timeouts() {
    show_status_panel
    echo -e "${AMARILLO}EDITAR TIMEOUTS EN NGINX${SEMCOR}"
    read -p "Dominio madre (nombre del archivo): " domain
    if [ -f "/etc/nginx/sites-available/$domain" ]; then
        nano "/etc/nginx/sites-available/$domain"
        systemctl reload nginx
    else
        msg -verm "No existe"
    fi
    read -p "Presiona ENTER..."
}

# 9) Balanceo de MADRES (VPS pool por dominio)
balanceo() {
    show_status_panel
    echo -e "${AMARILLO}BALANCEO DE CARGA (upstream)${SEMCOR}"
    echo "Función en desarrollo. Edita manualmente /etc/nginx/conf.d/upstream.conf"
    read -p "Presiona ENTER..."
}

# 10) Limitar ancho de banda (limit_rate)
limit_bandwidth() {
    show_status_panel
    echo -e "${AMARILLO}LIMITAR ANCHO DE BANDA${SEMCOR}"
    read -p "IP o Backend a limitar: " target
    read -p "Límite en KB/s (ej: 100): " rate
    msg -info "Debes agregar 'limit_rate ${rate}k;' en la configuración manualmente"
    read -p "Presiona ENTER..."
}

# 11) Tráfico por IP / Backend (stats)
traffic_stats() {
    show_status_panel
    echo -e "${AMARILLO}ESTADÍSTICAS DE TRÁFICO (acceso.log)${SEMCOR}"
    tail -n 50 /var/log/nginx/access.log | awk '{print $1}' | sort | uniq -c | sort -nr | head -10
    read -p "Presiona ENTER..."
}

# 12) Firewall UFW: abrir puerto
ufw_open() {
    show_status_panel
    echo -e "${AMARILLO}ABRIR PUERTO EN UFW${SEMCOR}"
    read -p "Puerto (80/443/otro): " port
    ufw allow $port/tcp
    ufw reload
    msg -verd "Puerto $port abierto"
    read -p "Presiona ENTER..."
}

# 13) Backup
backup_now() {
    show_status_panel
    mkdir -p "$BACKUP_DIR"
    local fecha=$(date '+%Y%m%d_%H%M%S')
    local archivo="$BACKUP_DIR/backends_$fecha.tar.gz"
    tar -czf "$archivo" "$USER_DATA" /etc/nginx/sites-available/* 2>/dev/null
    msg -verd "Backup creado: $archivo"
    read -p "Presiona ENTER..."
}

# 14) Restaurar backup
restore_backup() {
    show_status_panel
    echo -e "${AMARILLO}RESTAURAR BACKUP${SEMCOR}"
    ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null | nl
    read -p "Número de backup a restaurar: " num
    file=$(ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null | sed -n "${num}p")
    if [ -f "$file" ]; then
        tar -xzf "$file" -C /
        systemctl reload nginx
        msg -verd "Restaurado"
    else
        msg -verm "No válido"
    fi
    read -p "Presiona ENTER..."
}

# 15) Servicios de Nginx
nginx_services() {
    show_status_panel
    echo -e "${AMARILLO}SERVICIOS NGINX${SEMCOR}"
    echo "1) Status"
    echo "2) Stop"
    echo "3) Start"
    echo "4) Reload"
    echo "5) Restart"
    echo "6) Volver"
    read -p "Opción: " opt
    case $opt in
        1) systemctl status nginx --no-pager ;;
        2) systemctl stop nginx ;;
        3) systemctl start nginx ;;
        4) systemctl reload nginx ;;
        5) systemctl restart nginx ;;
        6) return ;;
        *) msg -verm "Inválido" ;;
    esac
    read -p "Presiona ENTER..."
}

# 16) Speedtest
speedtest() {
    show_status_panel
    echo -e "${AMARILLO}SPEEDTEST${SEMCOR}"
    if command -v speedtest-cli &>/dev/null; then
        speedtest-cli --simple
    else
        msg -verm "Instala speedtest-cli"
    fi
    read -p "Presiona ENTER..."
}

# 17) Mantenimiento programado
maintenance() {
    show_status_panel
    echo -e "${AMARILLO}MANTENIMIENTO PROGRAMADO${SEMCOR}"
    echo "1) Limpiar backends expirados ahora"
    echo "2) Programar limpieza automática (cron)"
    read -p "Opción: " opt
    case $opt in
        1)
            current=$(date +%s)
            if [ -f "$USER_DATA" ]; then
                awk -v c=$current -F: '{if ($4==0 || $4>c) print $0}' "$USER_DATA" > /tmp/users_clean
                mv /tmp/users_clean "$USER_DATA"
                msg -verd "Backends expirados eliminados"
            fi
            ;;
        2)
            (crontab -l 2>/dev/null; echo "0 * * * * /root/superc4mpeon.sh --clean-expired") | crontab -
            msg -verd "Cron añadido (cada hora)"
            ;;
        *) msg -verm "Inválido" ;;
    esac
    read -p "Presiona ENTER..."
}

# 18) Salir
salir() {
    exit 0
}

# ============ MENÚ PRINCIPAL CON ESTILO MEJORADO ============
while true; do
    show_status_panel
    echo -e " ${VERDE}[01]${SEMCOR} ${BLANCO}Dominios madre (crear / editar / eliminar)${SEMCOR}"
    echo -e " ${VERDE}[02]${SEMCOR} ${BLANCO}Agregar backend (nombre + IP + puerto)${SEMCOR}"
    echo -e " ${VERDE}[03]${SEMCOR} ${BLANCO}Listar backends (backend / IP / puerto)${SEMCOR}"
    echo -e " ${VERDE}[04]${SEMCOR} ${BLANCO}Listar dominios madre (servers)${SEMCOR}"
    echo -e " ${VERDE}[05]${SEMCOR} ${BLANCO}Eliminar backend${SEMCOR}"
    echo -e " ${VERDE}[06]${SEMCOR} ${BLANCO}Healthcheck (HTTP y latencia)${SEMCOR}"
    echo -e " ${VERDE}[07]${SEMCOR} ${BLANCO}Validar conexión (dominio + backend por header)${SEMCOR}"
    echo -e " ${VERDE}[08]${SEMCOR} ${BLANCO}Editar timeouts del dominio madre (manual por nombre)${SEMCOR}"
    echo -e " ${VERDE}[09]${SEMCOR} ${BLANCO}Balanceo de MADRES (VPS pool por dominio)${SEMCOR}"
    echo -e " ${VERDE}[10]${SEMCOR} ${BLANCO}Limitar ancho de banda por IP o Backend (limit_rate)${SEMCOR}"
    echo -e " ${VERDE}[11]${SEMCOR} ${BLANCO}Tráfico por IP / Backend (stats log + scanner)${SEMCOR}"
    echo -e " ${VERDE}[12]${SEMCOR} ${BLANCO}Firewall UFW: abrir puerto (80/443/otro)${SEMCOR}"
    echo -e " ${VERDE}[13]${SEMCOR} ${BLANCO}Backup${SEMCOR}"
    echo -e " ${VERDE}[14]${SEMCOR} ${BLANCO}Restaurar backup${SEMCOR}"
    echo -e " ${VERDE}[15]${SEMCOR} ${BLANCO}Servicios de Nginx (Status/Stop/Start/Reload/Restart)${SEMCOR}"
    echo -e " ${VERDE}[16]${SEMCOR} ${BLANCO}Speedtest (Ping / Bajada / Subida)${SEMCOR}"
    echo -e " ${VERDE}[17]${SEMCOR} ${BLANCO}Mantenimiento programado (RAM / Nginx timers)${SEMCOR}"
    echo -e " ${VERDE}[18]${SEMCOR} ${BLANCO}Salir${SEMCOR}"
    echo -e "${CIAN}════════════════════════════════════════════════════════${SEMCOR}"
    read -p "🔥 SELECCIONA OPCIÓN: " opcion

    case $opcion in
        1) manage_domains ;;
        2) add_backend ;;
        3) list_backends ;;
        4) list_domains ;;
        5) delete_backend ;;
        6) healthcheck ;;
        7) validate_connection ;;
        8) edit_timeouts ;;
        9) balanceo ;;
        10) limit_bandwidth ;;
        11) traffic_stats ;;
        12) ufw_open ;;
        13) backup_now ;;
        14) restore_backup ;;
        15) nginx_services ;;
        16) speedtest ;;
        17) maintenance ;;
        18) salir ;;
        *) msg -verm "Opción inválida"; sleep 2 ;;
    esac
done
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

echo -e "${VERDE}✅ Instalación completa. Ejecuta 'menu2' para iniciar el gestor de ${BLANCO}JOHNNY (@Jrcelulares)${SEMCOR}${VERDE}.${SEMCOR}"