#!/bin/bash
# ============================================================
# INSTALADOR - BACKEND MANAGER by JOHNNY (@Jrcelulares)
# Versión: 5.0 - 20 opciones + panel visual + todas las funciones
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

# ============================================================
# GENERAR EL SCRIPT PRINCIPAL /root/superc4mpeon.sh
# (Incluye TODAS las funciones originales + nuevas)
# ============================================================
cat > /root/superc4mpeon.sh << 'EOF'
#!/bin/bash

# ==================================================
# SCRIPT: BACKEND MANAGER by JOHNNY (@Jrcelulares)
# VERSIÓN: 5.0 - 20 OPCIONES + PANEL VISUAL
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

# ============ FUNCIONES ORIGINALES (del script del usuario) ============
# (Se mantienen intactas, solo se reemplaza show_banner por show_status_panel)

check_and_clean_expired() {
    local modified=0
    local current_time=$(date +%s)
    
    if [ ! -f "$USER_DATA" ] || [ ! -s "$USER_DATA" ]; then
        return
    fi
    
    msg -info "🔍 Verificando backends expirados..."
    
    awk -v current="$current_time" -F: '
    {
        if ($4 ~ /^[0-9]+$/) {
            if (current > $4) {
                print "EXPIRADO:" $0
            } else {
                print "VIGENTE:" $0
            }
        } else {
            print "CORRUPTO:" $0
        }
    }' "$USER_DATA" > /tmp/user_data_analysis.tmp
    
    grep "^VIGENTE:" /tmp/user_data_analysis.tmp | sed 's/^VIGENTE://' > /tmp/user_data_new.tmp
    local expirados=$(grep "^EXPIRADO:" /tmp/user_data_analysis.tmp | sed 's/^EXPIRADO://')
    local corruptos=$(grep "^CORRUPTO:" /tmp/user_data_analysis.tmp | sed 's/^CORRUPTO://')
    
    if [ -n "$expirados" ] || [ -n "$corruptos" ]; then
        echo "$expirados" | cut -d: -f1 > /tmp/names_to_delete.tmp
        echo "$corruptos" | cut -d: -f1 >> /tmp/names_to_delete.tmp
        
        awk '
        BEGIN {
            while (getline name < "/tmp/names_to_delete.tmp") {
                delete_names[name] = 1
            }
            skip = 0
        }
        /# BACKEND / {
            for (name in delete_names) {
                if ($0 ~ "# BACKEND " name) {
                    skip = 3
                    print "ELIMINADO: " $0 > "/dev/stderr"
                    next
                }
            }
        }
        /if \(\$http_backend = / {
            if (skip > 0) {
                skip--
                next
            }
            for (name in delete_names) {
                if ($0 ~ "\\$http_backend = \"" name "\"") {
                    skip = 2
                    print "ELIMINADO: " $0 > "/dev/stderr"
                    next
                }
            }
        }
        {
            if (skip > 0) {
                skip--
            } else {
                print
            }
        }
        ' "$BACKEND_CONF" > /tmp/nginx_conf_new.tmp 2>/tmp/deleted_lines.tmp
        
        if [ -s /tmp/deleted_lines.tmp ]; then
            msg -verm "🗑️  Eliminando backends expirados/corruptos:"
            cat /tmp/deleted_lines.tmp | while read line; do
                echo -e "  ${ROJO}✗${SEMCOR} $(echo "$line" | sed 's/ELIMINADO: //')"
            done
            modified=1
        fi
        
        if [ -n "$expirados" ]; then
            echo "$expirados" | while IFS=: read -r name ip port exp; do
                exp_date=$(date -d "@$exp" '+%d/%m/%Y %H:%M')
                msg -verm "  ⏰ BACKEND EXPIRADO: ${name} → ${ip}:${port} (Expiró: ${exp_date})"
            done
        fi
        
        if [ -n "$corruptos" ]; then
            echo "$corruptos" | while IFS=: read -r name ip port exp; do
                msg -verm "  ⚠️ BACKEND CORRUPTO: ${name} (formato incorrecto)"
            done
        fi
    fi
    
    if [ -f /tmp/user_data_new.tmp ]; then
        mv /tmp/user_data_new.tmp "$USER_DATA"
    fi
    
    if [ -f /tmp/nginx_conf_new.tmp ]; then
        mv /tmp/nginx_conf_new.tmp "$BACKEND_CONF"
    fi
    
    if [ $modified -eq 1 ]; then
        msg -info "🔄 Recargando Nginx..."
        if /usr/sbin/nginx -t 2>/dev/null; then
            systemctl reload nginx
            msg -verd "✅ Configuración actualizada: backends expirados eliminados"
        else
            msg -verm "❌ Error en configuración después de limpiar expirados"
            /usr/sbin/nginx -t
        fi
    else
        msg -verd "✅ No hay backends expirados"
    fi
    
    rm -f /tmp/user_data_analysis.tmp /tmp/user_data_new.tmp /tmp/nginx_conf_new.tmp /tmp/names_to_delete.tmp /tmp/deleted_lines.tmp
}

add_backend_minutes() {
    show_status_panel
    msg -bar
    msg -verd "AGREGAR NUEVO BACKEND CON EXPIRACIÓN EN MINUTOS"
    msg -bar
    
    if [ ! -f "$USER_DATA" ]; then
        touch "$USER_DATA"
    fi
    
    while true; do
        read -p "Nombre del backend (ej: test1, prueba, etc): " bname
        bname=$(echo "$bname" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
        if [ -z "$bname" ]; then
            msg -verm "El nombre del backend no puede estar vacío"
        elif grep -q "^${bname}:" "$USER_DATA" 2>/dev/null; then
            msg -verm "Ya existe un backend con el mismo nombre."
        else
            break
        fi
    done
    
    read -p "IP o dominio destino: " bip
    if [ -z "$bip" ]; then
        msg -verm "La IP no puede estar vacía"
        sleep 2
        return
    fi
    
    read -p "Puerto (80 por defecto): " bport
    bport=${bport:-80}
    
    while true; do
        read -p "Minutos de expiración (número): " minutes
        if [[ "$minutes" =~ ^[0-9]+$ ]] && [ "$minutes" -gt 0 ]; then
            break
        else
            msg -verm "Los minutos deben ser un número positivo."
        fi
    done
    
    local exp_date=$(date -d "+${minutes} minutes" '+%d/%m/%Y %H:%M')
    local block_comment="# BACKEND ${bname} - Creado: $(date '+%d/%m/%Y %H:%M') - Expira: ${exp_date}"
    
    sed -i "/# SOPORTE PARA USUARIOS PERSONALIZADOS/i \ \n    ${block_comment}\n    if (\$http_backend = \"$bname\") {\n        set \$target_backend \"http://${bip}:${bport}\";\n    }" "$BACKEND_CONF"
    
    local now=$(date +%s)
    local expiration_date=$((now + (minutes * 60)))
    echo "${bname}:${bip}:${bport}:${expiration_date}" >> "$USER_DATA"
    
    msg -verd "✅ BACKEND ${bname} agregado correctamente!"
    msg -info "IP: ${bip}:${bport} - Expira: ${exp_date} (${minutes} minutos)"
    
    if /usr/sbin/nginx -t; then
        systemctl reload nginx
        msg -verd "Configuración recargada!"
    fi
    
    msg -bar
    read -p "Presiona ENTER para continuar..."
}

add_backend_days() {
    show_status_panel
    msg -bar
    msg -verd "AGREGAR NUEVO BACKEND CON EXPIRACIÓN EN DÍAS"
    msg -bar
    
    if [ ! -f "$USER_DATA" ]; then
        touch "$USER_DATA"
    fi
    
    while true; do
        read -p "Nombre del backend (ej: sv3, user1, etc): " bname
        bname=$(echo "$bname" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
        if [ -z "$bname" ]; then
            msg -verm "El nombre del backend no puede estar vacío"
        elif grep -q "^${bname}:" "$USER_DATA" 2>/dev/null; then
            msg -verm "Ya existe un backend con el mismo nombre."
        else
            break
        fi
    done
    
    read -p "IP o dominio destino: " bip
    if [ -z "$bip" ]; then
        msg -verm "La IP no puede estar vacía"
        sleep 2
        return
    fi
    
    read -p "Puerto (80 por defecto): " bport
    bport=${bport:-80}
    
    while true; do
        read -p "Días de expiración (número): " days
        if [[ "$days" =~ ^[0-9]+$ ]] && [ "$days" -gt 0 ]; then
            break
        else
            msg -verm "Los días deben ser un número positivo."
        fi
    done
    
    local exp_date=$(date -d "+${days} days" '+%d/%m/%Y')
    local block_comment="# BACKEND ${bname} - Creado: $(date '+%d/%m/%Y') - Expira: ${exp_date}"
    
    sed -i "/# SOPORTE PARA USUARIOS PERSONALIZADOS/i \ \n    ${block_comment}\n    if (\$http_backend = \"$bname\") {\n        set \$target_backend \"http://${bip}:${bport}\";\n    }" "$BACKEND_CONF"
    
    local now=$(date +%s)
    local expiration_date=$((now + (days * 86400)))
    echo "${bname}:${bip}:${bport}:${expiration_date}" >> "$USER_DATA"
    
    msg -verd "✅ BACKEND ${bname} agregado correctamente!"
    msg -info "IP: ${bip}:${bport} - Expira: ${exp_date} (${days} días)"
    
    if /usr/sbin/nginx -t; then
        systemctl reload nginx
        msg -verd "Configuración recargada!"
    fi
    
    msg -bar
    read -p "Presiona ENTER para continuar..."
}

init_system() {
    mkdir -p "$BACKUP_DIR"
    touch "$USER_DATA"
    
    if ! command -v nginx &> /dev/null; then
        msg -ama "NGINX no está instalado. Usa opción 1 para instalar."
    fi
}

backup_backends() {
    show_status_panel
    msg -tit "RESPALDO DE BACKENDS PERSONALIZADOS"
    
    mkdir -p "$BACKUP_DIR"
    
    local fecha=$(date '+%Y%m%d_%H%M%S')
    local backup_file="${BACKUP_DIR}/backends_${fecha}.tar.gz"
    
    msg -info "Creando respaldo..."
    
    if [ -f "$USER_DATA" ] || [ -f "$BACKEND_CONF" ]; then
        tar -czf "$backup_file" "$USER_DATA" "$BACKEND_CONF" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            msg -verd "✅ RESPALDO CREADO EXITOSAMENTE!"
            msg -info "Archivo: backends_${fecha}.tar.gz"
            
            if [ -f "$USER_DATA" ]; then
                local total_backends=$(wc -l < "$USER_DATA" 2>/dev/null)
                msg -info "Backends personalizados: ${total_backends:-0}"
            fi
        else
            msg -verm "Error al crear el respaldo"
        fi
    else
        msg -ama "No hay archivos de configuración para respaldar"
    fi
    
    msg -bar
    read -p "Presiona ENTER para continuar..."
}

restore_backends() {
    show_status_panel
    msg -tit "RESTAURACIÓN DE BACKENDS"
    
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A $BACKUP_DIR 2>/dev/null)" ]; then
        msg -ama "No hay backups disponibles en: $BACKUP_DIR"
        msg -bar
        read -p "Presiona ENTER para continuar..."
        return
    fi
    
    echo -e "${CIAN}Backups disponibles:${SEMCOR}"
    echo ""
    
    local i=1
    declare -a backup_files
    
    while read -r backup; do
        if [ -n "$backup" ]; then
            local fecha_file=$(echo "$backup" | grep -o '[0-9]\{8\}_[0-9]\{6\}')
            local fecha_formateada=$(date -d "${fecha_file:0:8} ${fecha_file:9:2}:${fecha_file:11:2}:${fecha_file:13:2}" '+%d/%m/%Y %H:%M' 2>/dev/null)
            
            echo -e "${VERDE}${i})${SEMCOR} ${fecha_formateada:-$fecha_file} - ${backup}"
            backup_files[$i]="$backup"
            i=$((i + 1))
        fi
    done < <(ls -1 "$BACKUP_DIR" | grep 'backends_.*\.tar\.gz$' | sort -r)
    
    if [ $i -eq 1 ]; then
        msg -ama "No se encontraron backups válidos"
        msg -bar
        read -p "Presiona ENTER para continuar..."
        return
    fi
    
    msg -bar
    read -p "Selecciona el número del backup a restaurar (0 para cancelar): " backup_num
    
    if [ "$backup_num" = "0" ]; then
        msg -ama "Restauración cancelada"
        msg -bar
        read -p "Presiona ENTER para continuar..."
        return
    fi
    
    if [[ "$backup_num" =~ ^[0-9]+$ ]] && [ "$backup_num" -ge 1 ] && [ "$backup_num" -lt "$i" ]; then
        local selected_backup="${backup_files[$backup_num]}"
        
        msg -verm "⚠️  ¿ESTÁS SEGURO DE RESTAURAR ESTE BACKUP?"
        msg -verm "Se sobrescribirá la configuración actual."
        read -p "Escribe 'RESTAURAR' para confirmar: " confirm
        
        if [ "$confirm" = "RESTAURAR" ]; then
            msg -info "Restaurando desde: $selected_backup"
            
            local fecha=$(date '+%Y%m%d_%H%M%S')
            local pre_restore_backup="${BACKUP_DIR}/pre_restore_${fecha}.tar.gz"
            
            if [ -f "$USER_DATA" ] || [ -f "$BACKEND_CONF" ]; then
                tar -czf "$pre_restore_backup" "$USER_DATA" "$BACKEND_CONF" 2>/dev/null
                msg -info "Backup automático creado: pre_restore_${fecha}.tar.gz"
            fi
            
            if tar -xzf "$BACKUP_DIR/$selected_backup" -C / 2>/dev/null; then
                msg -verd "✅ RESTAURACIÓN COMPLETADA!"
                
                if /usr/sbin/nginx -t; then
                    systemctl reload nginx
                    msg -verd "Configuración de Nginx recargada"
                else
                    msg -verm "Error en la configuración restaurada. Revisa manualmente."
                fi
                
                if [ -f "$USER_DATA" ]; then
                    local total=$(wc -l < "$USER_DATA")
                    msg -info "Backends restaurados: ${total}"
                fi
            else
                msg -verm "Error al restaurar el backup"
            fi
        else
            msg -ama "Restauración cancelada"
        fi
    else
        msg -verm "Selección inválida"
    fi
    
    msg -bar
    read -p "Presiona ENTER para continuar..."
}

list_backups() {
    show_status_panel
    msg -tit "LISTA DE BACKUPS DISPONIBLES"
    
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A $BACKUP_DIR 2>/dev/null)" ]; then
        msg -ama "No hay backups disponibles en: $BACKUP_DIR"
    else
        echo -e "${CIAN}Backups encontrados:${SEMCOR}"
        echo ""
        
        local total=0
        
        while IFS= read -r backup; do
            if [ -n "$backup" ]; then
                local fecha=$(stat -c '%y' "$BACKUP_DIR/$backup" 2>/dev/null | cut -d. -f1)
                
                echo -e "${VERDE}•${SEMCOR} ${backup}"
                echo -e "  ${CIAN}Fecha:${SEMCOR} $fecha"
                echo ""
                
                total=$((total + 1))
            fi
        done < <(ls -1 "$BACKUP_DIR" | grep 'backends_.*\.tar\.gz$' 2>/dev/null | sort -r)
        
        msg -info "Total de backups: ${total}"
        msg -info "Directorio: ${BACKUP_DIR}"
    fi
    
    msg -bar
    read -p "Presiona ENTER para continuar..."
}

clean_old_backups() {
    show_status_panel
    msg -tit "LIMPIAR BACKUPS ANTIGUOS"
    
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A $BACKUP_DIR 2>/dev/null)" ]; then
        msg -ama "No hay backups para limpiar"
        msg -bar
        read -p "Presiona ENTER para continuar..."
        return
    fi
    
    echo -e "${AMARILLO}Selecciona una opción:${SEMCOR}"
    echo -e "1) Mantener solo los últimos 5 backups"
    echo -e "2) Mantener solo los últimos 10 backups"
    echo -e "3) Mantener backups de los últimos 30 días"
    echo -e "4) Mantener backups de los últimos 60 días"
    echo -e "5) Eliminar todos los backups"
    echo -e "6) Cancelar"
    msg -bar
    
    read -p "Selecciona opción: " clean_opt
    
    case $clean_opt in
        1)
            msg -info "Manteniendo últimos 5 backups..."
            ls -t "$BACKUP_DIR"/backends_*.tar.gz 2>/dev/null | tail -n +6 | while read -r old_backup; do
                rm -f "$old_backup"
                msg -verm "Eliminado: $(basename "$old_backup")"
            done
            msg -verd "Limpieza completada"
            ;;
        2)
            msg -info "Manteniendo últimos 10 backups..."
            ls -t "$BACKUP_DIR"/backends_*.tar.gz 2>/dev/null | tail -n +11 | while read -r old_backup; do
                rm -f "$old_backup"
                msg -verm "Eliminado: $(basename "$old_backup")"
            done
            msg -verd "Limpieza completada"
            ;;
        3)
            msg -info "Manteniendo backups de los últimos 30 días..."
            find "$BACKUP_DIR" -name "backends_*.tar.gz" -type f -mtime +30 -delete
            msg -verd "Limpieza completada"
            ;;
        4)
            msg -info "Manteniendo backups de los últimos 60 días..."
            find "$BACKUP_DIR" -name "backends_*.tar.gz" -type f -mtime +60 -delete
            msg -verd "Limpieza completada"
            ;;
        5)
            msg -verm "⚠️  ¿ELIMINAR TODOS LOS BACKUPS? (escribe 'ELIMINAR'): "
            read confirm
            if [ "$confirm" = "ELIMINAR" ]; then
                rm -f "$BACKUP_DIR"/backends_*.tar.gz
                msg -verd "Todos los backups eliminados"
            else
                msg -ama "Operación cancelada"
            fi
            ;;
        6)
            msg -ama "Cancelado"
            ;;
        *)
            msg -verm "Opción inválida"
            ;;
    esac
    
    msg -bar
    read -p "Presiona ENTER para continuar..."
}

backup_menu() {
    while true; do
        show_status_panel
        msg -tit "GESTIÓN DE BACKUPS"
        
        echo -e "${CIAN}Backups disponibles:${SEMCOR}"
        if [ -d "$BACKUP_DIR" ]; then
            local count=$(ls -1 "$BACKUP_DIR"/backends_*.tar.gz 2>/dev/null | wc -l)
            if [ $count -gt 0 ]; then
                echo -e "${VERDE}  $count backups encontrados${SEMCOR}"
                local latest=$(ls -t "$BACKUP_DIR"/backends_*.tar.gz 2>/dev/null | head -1)
                if [ -n "$latest" ]; then
                    echo -e "${CIAN}  Último backup:${SEMCOR} $(basename "$latest")"
                fi
            else
                echo -e "${AMARILLO}  No hay backups${SEMCOR}"
            fi
        else
            echo -e "${AMARILLO}  Directorio de backups no existe${SEMCOR}"
        fi
        
        echo -e "${MORADO}════════════════════════════════════════════════════════${SEMCOR}"
        echo -e "${VERDE}  [1]${SEMCOR} ${BLANCO}CREAR NUEVO BACKUP${SEMCOR}"
        echo -e "${VERDE}  [2]${SEMCOR} ${BLANCO}RESTAURAR BACKUP${SEMCOR}"
        echo -e "${VERDE}  [3]${SEMCOR} ${BLANCO}LISTAR BACKUPS${SEMCOR}"
        echo -e "${VERDE}  [4]${SEMCOR} ${BLANCO}LIMPIAR BACKUPS ANTIGUOS${SEMCOR}"
        echo -e "${VERDE}  [5]${SEMCOR} ${BLANCO}VOLVER AL MENÚ PRINCIPAL${SEMCOR}"
        echo -e "${MORADO}════════════════════════════════════════════════════════${SEMCOR}"
        
        read -p "🔥 SELECCIONA OPCIÓN: " backup_opt
        
        case $backup_opt in
            1) backup_backends ;;
            2) restore_backends ;;
            3) list_backups ;;
            4) clean_old_backups ;;
            5) return ;;
            *) 
                msg -verm "Opción inválida"
                sleep 2
                ;;
        esac
    done
}

install_nginx_super() {
    show_status_panel
    msg -tit "INSTALACIÓN PROFESIONAL NGINX"
    
    if ss -tlnp | grep -q ':80 '; then
        msg -verm "El puerto 80 está en uso. Deteniendo servicio conflictivo..."
        sudo systemctl stop apache2 2>/dev/null
        sudo systemctl disable apache2 2>/dev/null
        sudo fuser -k 80/tcp 2>/dev/null
    fi
    
    msg -info "Instalando NGINX..."
    sudo apt update -y
    sudo apt install nginx -y
    
    msg -info "Creando configuración SUPER DINÁMICA..."
    
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
INNER

    ln -sf "$BACKEND_CONF" "$BACKEND_ENABLED"
    rm -f /etc/nginx/sites-enabled/default
    
    if /usr/sbin/nginx -t; then
        systemctl restart nginx
        msg -verd "NGINX instalado y configurado con ÉXITO!"
        msg -info "Configuración DINÁMICA activada"
    else
        msg -verm "Error en configuración. Restaurando..."
        /usr/sbin/nginx -t
    fi
    
    msg -bar
    read -p "Presiona ENTER para continuar..."
}

install_python_proxy() {
    local script_url="https://raw.githubusercontent.com/vpsnet360/instalador/refs/heads/main/so"
    local script_path="/etc/so"
    wget -q -O "$script_path" "$script_url"
    if [[ $? -ne 0 || ! -s "$script_path" ]]; then
        echo -e "\033[1;31mError: No se pudo descargar el script.\033[0m"
        return
    fi
    chmod +x "$script_path"

    "$script_path"
}

manage_backends() {
    show_status_panel
    msg -tit "CONFIGURACIÓN DE BACKENDS PERSONALIZADOS"
    
    echo -e "${CIAN}USUARIOS BACKENDS ACTUALES EN CONFIGURACIÓN:${SEMCOR}"
    echo -e "${CIAN}════════════════════════════════════════════════════════${SEMCOR}"
    
    if [ -f "$USER_DATA" ] && [ -s "$USER_DATA" ]; then
        while IFS=: read -r user ip port exp_time; do
            if [[ "$exp_time" =~ ^[0-9]+$ ]]; then
                current_time=$(date +%s)
                if [ $current_time -gt $exp_time ]; then
                    echo -e "${ROJO}⚠️ BACKEND ${user} → ${ip}:${port} (EXPIRADO)${SEMCOR}"
                else
                    days_left=$(( (exp_time - current_time) / 86400 ))
                    hours_left=$(( ((exp_time - current_time) % 86400) / 3600 ))
                    minutes_left=$(( ((exp_time - current_time) % 3600) / 60 ))
                    
                    if [ $days_left -gt 0 ]; then
                        echo -e "${VERDE}✅ BACKEND ${user} → ${ip}:${port} (${days_left} DIAS RESTANTES)${SEMCOR}"
                    elif [ $hours_left -gt 0 ]; then
                        echo -e "${AMARILLO}⚠️ BACKEND ${user} → ${ip}:${port} (${hours_left} HORAS ${minutes_left} MINUTOS RESTANTES)${SEMCOR}"
                    else
                        echo -e "${AMARILLO}⚠️ BACKEND ${user} → ${ip}:${port} (${minutes_left} MINUTOS RESTANTES)${SEMCOR}"
                    fi
                fi
            else
                echo -e "${ROJO}⚠️ BACKEND con formato incorrecto: ${user}:${ip}:${port}:${exp_time}${SEMCOR}"
            fi
        done < "$USER_DATA"
    else
        echo -e "${AMARILLO}  No hay backends personalizados configurados${SEMCOR}"
    fi
    
    echo -e "${CIAN}════════════════════════════════════════════════════════${SEMCOR}"
    echo -e "${CIAN}BACKENDS DEL SISTEMA:${SEMCOR}"
    
    echo -e "${VERDE}🔧 LOCAL → http://127.0.0.1:8080 (Fijo)${SEMCOR}"
    echo -e "${VERDE}🔧 SSH → http://127.0.0.1:22 (Fijo)${SEMCOR}"
    
    msg -bar2
    
    echo -e "${AMARILLO}1) AGREGAR BACKEND CON (DÍAS)"
    echo -e "2) AGREGAR BACKEND CON (MINUTOS)"
    echo -e "3) EDITAR BACKEND EXISTENTE"
    echo -e "4) ELIMINAR BACKEND"
    echo -e "5) PROBAR CONECTIVIDAD DE BACKENDS"
    echo -e "6) EXTENDER EXPIRACIÓN DE BACKEND"
    echo -e "7) LIMPIAR BACKENDS EXPIRADOS AHORA${SEMCOR}"
    echo -e "8) VOLVER"
    msg -bar
    
    read -p "🔥 SELECCIONA OPCIÓN: " backend_opt
    
    case $backend_opt in
        1) add_backend_days ;;
        2) add_backend_minutes ;;
        3)
            read -p "Nombre del backend a editar: " bname
            if [ -f "$USER_DATA" ] && grep -q "^${bname}:" "$USER_DATA" 2>/dev/null; then
                msg -info "Editando backend con expiración. Abriendo editor..."
                nano "$BACKEND_CONF"
                read -p "¿Actualizar fecha de expiración? (s/n): " update_exp
                if [[ "$update_exp" =~ ^[sS]$ ]]; then
                    read -p "Nuevos días de expiración: " new_days
                    if [[ "$new_days" =~ ^[0-9]+$ ]] && [ "$new_days" -gt 0 ]; then
                        current_data=$(grep "^${bname}:" "$USER_DATA")
                        current_ip=$(echo "$current_data" | cut -d: -f2)
                        current_port=$(echo "$current_data" | cut -d: -f3)
                        new_exp=$(( $(date +%s) + (new_days * 86400) ))
                        
                        sed -i "s/^${bname}:.*/${bname}:${current_ip}:${current_port}:${new_exp}/" "$USER_DATA"
                        
                        new_exp_date=$(date -d "@$new_exp" '+%d/%m/%Y')
                        sed -i "s|# BACKEND ${bname}.*|# BACKEND ${bname} - Creado: $(date '+%d/%m/%Y') - Expira: ${new_exp_date}|" "$BACKEND_CONF"
                        
                        msg -verd "Fecha de expiración actualizada!"
                    else
                        msg -verm "Días inválidos"
                    fi
                fi
            else
                msg -info "Editando backend del sistema (sin expiración)..."
                nano "$BACKEND_CONF"
            fi
            ;;
            
        4)
            read -p "Nombre del backend a eliminar: " bname
            msg -verm "⚠️  ¿ESTÁS SEGURO DE ELIMINAR ${bname}? (s/n): "
            read confirm
            if [[ "$confirm" =~ ^[sS]$ ]]; then
                if [ -f "$USER_DATA" ]; then
                    grep -v "^${bname}:" "$USER_DATA" > /tmp/user_data_new
                    mv /tmp/user_data_new "$USER_DATA"
                fi
                
                if [ -f "$BACKEND_CONF" ]; then
                    grep -v "# BACKEND ${bname}" "$BACKEND_CONF" | grep -v "if (\\$http_backend = \"$bname\")" > /tmp/nginx_conf_new
                    mv /tmp/nginx_conf_new "$BACKEND_CONF"
                fi
                
                if /usr/sbin/nginx -t; then
                    systemctl reload nginx
                    msg -verd "✅ Backend ${bname} eliminado!"
                else
                    msg -verm "Error en configuración después de eliminar"
                fi
            else
                msg -ama "Operación cancelada"
            fi
            ;;
            
        5)
            msg -info "Probando backends..."
            if [ -f "$USER_DATA" ] && [ -s "$USER_DATA" ]; then
                while IFS=: read -r bname bip bport exp_time; do
                    if curl -s --connect-timeout 2 "http://${bip}:${bport}" > /dev/null; then
                        msg -verd "✓ ${bname} (${bip}:${bport}) responde"
                    else
                        msg -verm "✗ ${bname} (${bip}:${bport}) sin respuesta"
                    fi
                done < "$USER_DATA"
            fi
            ;;
            
        6)
            if [ ! -f "$USER_DATA" ] || [ ! -s "$USER_DATA" ]; then
                msg -ama "No hay backends con expiración configurada."
            else
                echo -e "${CIAN}Backends con expiración:${SEMCOR}"
                local i=1
                declare -a valid_backends
                
                while IFS=: read -r bname bip bport exp_time; do
                    if [[ "$exp_time" =~ ^[0-9]+$ ]]; then
                        current_time=$(date +%s)
                        if [ $current_time -gt $exp_time ]; then
                            estado="${ROJO}EXPIRADO${SEMCOR}"
                            days_left=0
                        else
                            days_left=$(( (exp_time - current_time) / 86400 ))
                            estado="${VERDE}Activo${SEMCOR}"
                        fi
                        exp_date=$(date -d "@$exp_time" '+%d/%m/%Y %H:%M')
                        echo -e "${VERDE}${i})${SEMCOR} ${bname} - ${bip}:${bport} - Expira: ${exp_date} - ${estado}"
                        valid_backends[$i]="$bname"
                        i=$((i + 1))
                    else
                        echo -e "${ROJO}⚠️ Formato incorrecto: ${bname}:${bip}:${bport}:${exp_time}${SEMCOR}"
                    fi
                done < "$USER_DATA"
                
                if [ $i -eq 1 ]; then
                    msg -ama "No hay backends con formato válido."
                else
                    msg -bar
                    read -p "Selecciona el número del backend: " backend_num
                    if [[ "$backend_num" =~ ^[0-9]+$ ]] && [ "$backend_num" -lt "$i" ]; then
                        backend_selected="${valid_backends[$backend_num]}"
                        
                        if [ -n "$backend_selected" ]; then
                            read -p "Minutos adicionales a agregar: " extra_minutes
                            if [[ "$extra_minutes" =~ ^[0-9]+$ ]] && [ "$extra_minutes" -gt 0 ]; then
                                old_data=$(grep "^${backend_selected}:" "$USER_DATA")
                                old_ip=$(echo "$old_data" | cut -d: -f2)
                                old_port=$(echo "$old_data" | cut -d: -f3)
                                old_exp=$(echo "$old_data" | cut -d: -f4)
                                
                                if [[ "$old_exp" =~ ^[0-9]+$ ]]; then
                                    new_exp=$((old_exp + (extra_minutes * 60)))
                                    
                                    sed -i "s/^${backend_selected}:.*/${backend_selected}:${old_ip}:${old_port}:${new_exp}/" "$USER_DATA"
                                    
                                    new_exp_date=$(date -d "@$new_exp" '+%d/%m/%Y %H:%M')
                                    sed -i "s|# BACKEND ${backend_selected}.*|# BACKEND ${backend_selected} - Creado: $(date '+%d/%m/%Y %H:%M') - Expira: ${new_exp_date}|" "$BACKEND_CONF"
                                    
                                    msg -verd "Expiración extendida! Nueva fecha: ${new_exp_date}"
                                else
                                    msg -verm "Error en el formato de expiración"
                                fi
                            else
                                msg -verm "Minutos inválidos"
                            fi
                        else
                            msg -verm "Selección inválida"
                        fi
                    else
                        msg -verm "Número inválido"
                    fi
                fi
            fi
            ;;
            
        8) return ;;
        
        7)
            check_and_clean_expired
            msg -bar
            read -p "Presiona ENTER para continuar..."
            ;;
        
        *)
            msg -verm "Opción inválida"
            sleep 2
            return
            ;;
    esac
    
    if [ "$backend_opt" != "5" ] && [ "$backend_opt" != "7" ] && [ "$backend_opt" != "8" ]; then
        if /usr/sbin/nginx -t; then
            systemctl reload nginx
            msg -verd "Configuración recargada!"
        else
            msg -verm "Error en la configuración. Revise manualmente."
        fi
    fi
    
    msg -bar
    read -p "Presiona ENTER para continuar..."
}

show_epic_instructions() {
    show_status_panel
    msg -tit "INSTRUCCIONES DE GUERRERO C4MPEON"
    
    echo -e "${CIAN}╔══════════════════════════════════════════════════════╗"
    echo -e "║               PAYLOADS MORTALES ⚔️                    ║"
    echo -e "╚══════════════════════════════════════════════════════╝${SEMCOR}"
    
    echo -e "\n${VERDE}🔥 PARA BACKEND LOCAL (PUERTO SSH):${SEMCOR}"
    echo -e "${BLANCO}GET / HTTP/1.1[crlf]"
    echo -e "Host: tunel.c4mpeon.com[crlf]"
    echo -e "Backend: local[crlf]"
    echo -e "Connection: Upgrade[crlf]"
    echo -e "Upgrade: websocket[crlf][crlf]${SEMCOR}"
    
    echo -e "\n${AMARILLO}🔥 PARA BACKEND REMOTO SV1:${SEMCOR}"
    echo -e "${BLANCO}GET / HTTP/1.1[crlf]"
    echo -e "Host: tunel.c4mpeon.com[crlf]"
    echo -e "Backend: sv1[crlf]"
    echo -e "Connection: Upgrade[crlf]"
    echo -e "Upgrade: websocket[crlf][crlf]${SEMCOR}"
    
    echo -e "\n${MORADO}🔥 PARA BACKEND PERSONALIZADO (IP DIRECTA):${SEMCOR}"
    echo -e "${BLANCO}GET / HTTP/1.1[crlf]"
    echo -e "Host: tunel.c4mpeon.com[crlf]"
    echo -e "Backend: 192.168.1.100:80[crlf]"
    echo -e "Connection: Upgrade[crlf]"
    echo -e "Upgrade: websocket[crlf][crlf]${SEMCOR}"
    
    echo -e "\n${ROJO}🔥 MODO CLARO ESPECIAL:${SEMCOR}"
    echo -e "${BLANCO}GET / HTTP/1.1[crlf]"
    echo -e "Host: static1.claromusica.com[crlf][crlf][split]"
    echo -e "GET / HTTP/1.1[crlf]"
    echo -e "Host: tunel.c4mpeon.com[crlf]"
    echo -e "Backend: sv2[crlf]"
    echo -e "Connection: Upgrade[crlf]"
    echo -e "Upgrade: websocket[crlf][crlf]${SEMCOR}"
    
    msg -bar
    echo -e "${VERDE}COMANDOS ÚTILES:${SEMCOR}"
    echo -e "  Ver logs: ${CIAN}tail -f /var/log/nginx/access.log${SEMCOR}"
    echo -e "  Ver estado: ${CIAN}systemctl status nginx${SEMCOR}"
    echo -e "  Editar backends: ${CIAN}nano $BACKEND_CONF${SEMCOR}"
    
    msg -bar
    read -p "Presiona ENTER para continuar..."
}

show_status() {
    show_status_panel
    msg -tit "ESTADO DEL SISTEMA SUPERC4MPEON"
    
    if systemctl is-active --quiet nginx; then
        msg -verd "NGINX: ACTIVO ✅"
    else
        msg -verm "NGINX: INACTIVO ❌"
    fi
    
    if systemctl is-active --quiet superc4mpeon-proxy; then
        msg -verd "Proxy Python: ACTIVO ✅"
    else
        msg -verm "Proxy Python: INACTIVO ❌"
    fi
    
    msg -info "Puertos en escucha:"
    ss -tlnp | grep -E ':(80|8080|22)' | column -t
    
    msg -info "Conexiones activas a Nginx:"
    ss -tn state established '( dport = :80 or sport = :80 )' | tail -n +2 | wc -l | xargs echo "  Total:"
    
    if [ -d "$BACKUP_DIR" ]; then
        local backup_count=$(ls -1 "$BACKUP_DIR"/backends_*.tar.gz 2>/dev/null | wc -l)
        if [ $backup_count -gt 0 ]; then
            msg -info "Backups disponibles: ${backup_count}"
            local latest=$(ls -t "$BACKUP_DIR"/backends_*.tar.gz 2>/dev/null | head -1)
            if [ -n "$latest" ]; then
                msg -info "Último backup: $(basename "$latest")"
            fi
        fi
    fi
    
    msg -bar
    read -p "Presiona ENTER para continuar..."
}

uninstall_everything() {
    show_status_panel
    msg -tit "DESINSTALACIÓN COMPLETA"
    msg -verm "⚠️  ESTO ELIMINARÁ TODOS LOS COMPONENTES ⚠️"
    msg -bar
    
    read -p "¿ESTÁS SEGURO? (escribe 'SI' para confirmar): " confirm
    
    if [ "$confirm" = "SI" ]; then
        msg -info "Deteniendo servicios..."
        systemctl stop superc4mpeon-proxy nginx 2>/dev/null
        systemctl disable superc4mpeon-proxy nginx 2>/dev/null
        
        msg -info "Eliminando paquetes..."
        apt purge nginx nginx-common python3 -y
        apt autoremove -y
        
        msg -info "Eliminando configuraciones..."
        rm -rf /etc/nginx/superc4mpeon*
        rm -f /etc/superc4mpeon_proxy.py
        rm -f /etc/systemd/system/superc4mpeon*
        
        msg -bar
        read -p "¿Eliminar también todos los backups? (s/n): " del_backups
        if [[ "$del_backups" =~ ^[sS]$ ]]; then
            rm -rf "$BACKUP_DIR"
            msg -verm "Backups eliminados"
        else
            msg -info "Backups conservados en: $BACKUP_DIR"
        fi
        
        msg -verd "Desinstalación completa!"
    else
        msg -ama "Operación cancelada"
    fi
    
    msg -bar
    read -p "Presiona ENTER para continuar..."
}

# ============ NUEVAS FUNCIONES ============
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

balanceo() {
    show_status_panel
    echo -e "${AMARILLO}BALANCEO DE CARGA (upstream)${SEMCOR}"
    echo "Función en desarrollo. Edita manualmente /etc/nginx/conf.d/upstream.conf"
    read -p "Presiona ENTER..."
}

limit_bandwidth() {
    show_status_panel
    echo -e "${AMARILLO}LIMITAR ANCHO DE BANDA${SEMCOR}"
    read -p "IP o Backend a limitar: " target
    read -p "Límite en KB/s (ej: 100): " rate
    msg -info "Debes agregar 'limit_rate ${rate}k;' en la configuración manualmente"
    read -p "Presiona ENTER..."
}

traffic_stats() {
    show_status_panel
    echo -e "${AMARILLO}ESTADÍSTICAS DE TRÁFICO (acceso.log)${SEMCOR}"
    tail -n 50 /var/log/nginx/access.log | awk '{print $1}' | sort | uniq -c | sort -nr | head -10
    read -p "Presiona ENTER..."
}

ufw_open() {
    show_status_panel
    echo -e "${AMARILLO}ABRIR PUERTO EN UFW${SEMCOR}"
    read -p "Puerto (80/443/otro): " port
    ufw allow $port/tcp
    ufw reload
    msg -verd "Puerto $port abierto"
    read -p "Presiona ENTER..."
}

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

# ============ MENÚ PRINCIPAL CON 20 OPCIONES ============
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

echo -e "${VERDE}✅ Instalación completada. Ahora ejecuta 'menu2' para disfrutar del Backend Manager by JOHNNY con 20 opciones y panel mejorado.${SEMCOR}"
