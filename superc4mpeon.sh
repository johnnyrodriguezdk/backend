#!/bin/bash

# ==================================================
# SCRIPT: superc4mpeon - GESTOR BACKEND CLOUDFRONT
# VERSIÓN: 4.0 - CON MONITOR DE RECURSOS EN TIEMPO REAL
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
ROSA='\e[1;95m'
TURQUESA='\e[1;96m'

# ARCHIVOS DE CONFIGURACIÓN
BACKEND_CONF="/etc/nginx/sites-available/superc4mpeon"
BACKEND_ENABLED="/etc/nginx/sites-enabled/superc4mpeon"
USER_DATA="/etc/nginx/superc4mpeon_users.txt"
BACKUP_DIR="/root/superc4mpeon_backups"

# ============ FUNCIÓN DE MENSAJES PROFESIONAL ============
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

# ============ BANNER SUPER PROFESIONAL ============
show_banner() {
    clear
    echo -e "${TURQUESA}════════════════════════════════════════════════════════${SEMCOR}"
    echo -e "\E[41;1;37m                GESTOR BACKEND CLOUDFRONT V6.0                 \E[0m"
    echo -e "${TURQUESA}════════════════════════════════════════════════════════${SEMCOR}"
}

SCRIPT_PATH="/root/superc4mpeon.sh"
LINK_PATH="/bin/menu2"

if [ ! -f "$SCRIPT_PATH" ]; then
    exit 1
fi

if [ ! -L "$LINK_PATH" ]; then
    sudo ln -s "$SCRIPT_PATH" "$LINK_PATH"
    sudo chmod +x "$LINK_PATH"
fi

if [ ! -x "$SCRIPT_PATH" ]; then
    sudo chmod +x "$SCRIPT_PATH"
fi

# ============ FORMATO DE BYTES ============
format_bytes() {
    local bytes=$1
    if [ $bytes -ge 1099511627776 ]; then  # TB
        echo "$(awk "BEGIN {printf \"%.2f TB\"}" $((bytes / 1099511627776)))"
    elif [ $bytes -ge 1073741824 ]; then  # GB
        echo "$(awk "BEGIN {printf \"%.2f GB\"}" $((bytes / 1073741824)))"
    elif [ $bytes -ge 1048576 ]; then     # MB
        echo "$(awk "BEGIN {printf \"%.2f MB\"}" $((bytes / 1048576)))"
    elif [ $bytes -ge 1024 ]; then         # KB
        echo "$(awk "BEGIN {printf \"%.2f KB\"}" $((bytes / 1024)))"
    else
        echo "${bytes} B"
    fi
}

# ============ MONITOR DE RECURSOS BÁSICO ============
show_resource_monitor() {
    show_banner
    msg -tit "📊 MONITOR DE RECURSOS DEL SISTEMA"

    # Uptime
    local uptime_info=$(uptime | sed 's/.*up \([^,]*\),.*/\1/')
    msg -info "⏱️  Tiempo activo: $uptime_info"

    # CPU
    msg -bar2
    msg -azu "💻 USO DE CPU:"
    local cpu1 user1 nice1 system1 idle1 iowait1 irq1 softirq1 steal1
    read cpu1 user1 nice1 system1 idle1 iowait1 irq1 softirq1 steal1 < /proc/stat
    local total1=$((user1 + nice1 + system1 + idle1 + iowait1 + irq1 + softirq1 + steal1))
    local idle1=$idle1
    sleep 1
    read cpu2 user2 nice2 system2 idle2 iowait2 irq2 softirq2 steal2 < /proc/stat
    local total2=$((user2 + nice2 + system2 + idle2 + iowait2 + irq2 + softirq2 + steal2))
    local idle2=$idle2
    local cpu_usage=$(awk -v id1="$idle1" -v tot1="$total1" -v id2="$idle2" -v tot2="$total2" 'BEGIN {
        if (tot2 - tot1 > 0) printf "%.1f", 100 * (1 - (id2 - id1) / (tot2 - tot1)
        else print "0.0"
    }')
    echo -e "${VERDE}  Uso actual: ${cpu_usage}%${SEMCOR}"

    # RAM
    msg -bar2
    msg -azu "🧠 MEMORIA RAM:"
    free -h | awk '/^Mem:/ {
        total = $2
        used = $3
        free = $4
        gsub(/[^0-9.]/, "", used)
        gsub(/[^0-9.]/, "", total)
        printf "  Total: %s  Usada: %s  Libre: %s  (%.1f%% usada)\n", $2, $3, $4, (used/total)*100
    }'

    # Red
    msg -bar2
    msg -azu "🌐 TRÁFICO DE RED (desde arranque):"
    if [ -r /proc/net/dev ]; then
        tail -n +3 /proc/net/dev | while read line; do
            if [[ $line != lo:* ]]; then
                iface=$(echo $line | cut -d: -f1 | tr -d ' ')
                rx=$(echo $line | awk '{print $2}')
                tx=$(echo $line | awk '{print $10}')
                rx_f=$(format_bytes $rx)
                tx_f=$(format_bytes $tx)
                echo -e "${VERDE}  $iface:${SEMCOR} RX $rx_f  TX $tx_f"
            fi
        done
    else
        msg -verm "  No se puede acceder a /proc/net/dev"
    fi

    msg -bar
    read -p "Presiona ENTER para continuar..."
}

# ============ MONITOR EN TIEMPO REAL ============
show_realtime_monitor() {
    clear
    msg -tit "📈 MONITOR EN TIEMPO REAL (CTRL+C PARA SALIR)"
    echo -e "${AMARILLO}Actualizando cada 2 segundos...${SEMCOR}"
    msg -bar
    sleep 2

    # Valores iniciales de red
    local old_rx=0 old_tx=0
    local old_total=0
    if [ -r /proc/net/dev ]; then
        local first_line=$(tail -n +3 /proc/net/dev | grep -v lo: | head -1)
        old_rx=$(echo $first_line | awk '{print $2}')
        old_tx=$(echo $first_line | awk '{print $10}')
        old_total=$((old_rx + old_tx))
    fi

    while true; do
        clear
        echo -e "${TURQUESA}════════════════════════════════════════════════════════${SEMCOR}"
        echo -e "${BLANCO}${NEGRITO}         MONITOR EN TIEMPO REAL (CTRL+C SALIR)${SEMCOR}"
        echo -e "${TURQUESA}════════════════════════════════════════════════════════${SEMCOR}"

        # Hora actual
        echo -e "${CIAN}⏱️  $(date '+%H:%M:%S')${SEMCOR}"

        # CPU
        local cpu1 user1 nice1 system1 idle1 iowait1 irq1 softirq1 steal1
        read cpu1 user1 nice1 system1 idle1 iowait1 irq1 softirq1 steal1 < /proc/stat
        local total1=$((user1 + nice1 + system1 + idle1 + iowait1 + irq1 + softirq1 + steal1))
        local idle1=$idle1
        sleep 1
        read cpu2 user2 nice2 system2 idle2 iowait2 irq2 softirq2 steal2 < /proc/stat
        local total2=$((user2 + nice2 + system2 + idle2 + iowait2 + irq2 + softirq2 + steal2))
        local idle2=$idle2
        local cpu_usage=$(awk -v id1="$idle1" -v tot1="$total1" -v id2="$idle2" -v tot2="$total2" 'BEGIN {
            if (tot2 - tot1 > 0) printf "%.1f", 100 * (1 - (id2 - id1) / (tot2 - tot1)
            else print "0.0"
        }')
        echo -e "${VERDE}💻 CPU: ${cpu_usage}%${SEMCOR}"

        # RAM
        local ram_line=$(free -b | grep Mem:)
        local ram_total=$(echo $ram_line | awk '{print $2}')
        local ram_used=$(echo $ram_line | awk '{print $3}')
        local ram_percent=$(awk "BEGIN {printf \"%.1f\"}" $((ram_used * 100 / ram_total)))
        local ram_used_f=$(format_bytes $ram_used)
        local ram_total_f=$(format_bytes $ram_total)
        echo -e "${AZUL}🧠 RAM: ${ram_used_f} / ${ram_total_f} (${ram_percent}%)${SEMCOR}"

        # RED en tiempo real
        if [ -r /proc/net/dev ]; then
            local new_line=$(tail -n +3 /proc/net/dev | grep -v lo: | head -1)
            local new_rx=$(echo $new_line | awk '{print $2}')
            local new_tx=$(echo $new_line | awk '{print $10}')
            local new_total=$((new_rx + new_tx))
            
            local rx_speed=$((new_rx - old_rx))
            local tx_speed=$((new_tx - old_tx))
            local total_speed=$((new_total - old_total))
            
            local rx_speed_f=$(format_bytes $rx_speed)
            local tx_speed_f=$(format_bytes $tx_speed)
            local total_speed_f=$(format_bytes $total_speed)
            
            echo -e "${CIAN}🌐 RED (últimos 2s):${SEMCOR}"
            echo -e "  📥 RX: ${VERDE}${rx_speed_f}/s${SEMCOR}"
            echo -e "  📤 TX: ${VERDE}${tx_speed_f}/s${SEMCOR}"
            echo -e "  📊 Total: ${AMARILLO}${total_speed_f}/s${SEMCOR}"
            
            old_rx=$new_rx
            old_tx=$new_tx
        fi

        # Conexiones activas
        local connections=$(ss -tn state established '( dport = :80 or sport = :80 )' 2>/dev/null | tail -n +2 | wc -l)
        echo -e "${MORADO}🔌 Conexiones activas (puerto 80): ${connections}${SEMCOR}"

        msg -bar
        echo -e "${AMARILLO}Presiona CTRL+C para volver al menú${SEMCOR}"
        sleep 2
    done
}

# ============ VERIFICAR Y ELIMINAR BACKENDS EXPIRADOS (CON AWK) ============
check_and_clean_expired() {
    local modified=0
    local current_time=$(date +%s)
    
    if [ ! -f "$USER_DATA" ] || [ ! -s "$USER_DATA" ]; then
        return
    fi
    
    msg -info "🔍 Verificando backends expirados..."
    
    # ===== PROCESAR USER_DATA CON AWK =====
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
    
    # Crear nuevo USER_DATA solo con vigentes
    grep "^VIGENTE:" /tmp/user_data_analysis.tmp | sed 's/^VIGENTE://' > /tmp/user_data_new.tmp
    
    # Procesar expirados y corruptos
    local expirados=$(grep "^EXPIRADO:" /tmp/user_data_analysis.tmp | sed 's/^EXPIRADO://')
    local corruptos=$(grep "^CORRUPTO:" /tmp/user_data_analysis.tmp | sed 's/^CORRUPTO://')
    
    # ===== ELIMINAR DE NGINX CON AWK =====
    if [ -n "$expirados" ] || [ -n "$corruptos" ]; then
        # Crear lista de nombres a eliminar
        echo "$expirados" | cut -d: -f1 > /tmp/names_to_delete.tmp
        echo "$corruptos" | cut -d: -f1 >> /tmp/names_to_delete.tmp
        
        # Procesar BACKEND_CONF con AWK para eliminar los backends
        awk '
        BEGIN {
            # Cargar nombres a eliminar
            while (getline name < "/tmp/names_to_delete.tmp") {
                delete_names[name] = 1
            }
            skip = 0
        }
        /# BACKEND / {
            # Verificar si este backend debe ser eliminado
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
            # Verificar si este if debe ser eliminado
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
        
        # Mostrar qué se eliminó
        if [ -s /tmp/deleted_lines.tmp ]; then
            msg -verm "🗑️  Eliminando backends expirados/corruptos:"
            cat /tmp/deleted_lines.tmp | while read line; do
                echo -e "  ${ROJO}✗${SEMCOR} $(echo "$line" | sed 's/ELIMINADO: //')"
            done
            modified=1
        fi
        
        # Mostrar expirados
        if [ -n "$expirados" ]; then
            echo "$expirados" | while IFS=: read -r name ip port exp; do
                exp_date=$(date -d "@$exp" '+%d/%m/%Y %H:%M')
                msg -verm "  ⏰ BACKEND EXPIRADO: ${name} → ${ip}:${port} (Expiró: ${exp_date})"
            done
        fi
        
        # Mostrar corruptos
        if [ -n "$corruptos" ]; then
            echo "$corruptos" | while IFS=: read -r name ip port exp; do
                msg -verm "  ⚠️ BACKEND CORRUPTO: ${name} (formato incorrecto)"
            done
        fi
    fi
    
    # ===== ACTUALIZAR ARCHIVOS =====
    if [ -f /tmp/user_data_new.tmp ]; then
        mv /tmp/user_data_new.tmp "$USER_DATA"
    fi
    
    if [ -f /tmp/nginx_conf_new.tmp ]; then
        mv /tmp/nginx_conf_new.tmp "$BACKEND_CONF"
    fi
    
    # ===== RECARGAR NGINX SI HUBO CAMBIOS =====
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
    
    # Limpiar archivos temporales
    rm -f /tmp/user_data_analysis.tmp /tmp/user_data_new.tmp /tmp/nginx_conf_new.tmp /tmp/names_to_delete.tmp /tmp/deleted_lines.tmp
}

# ============ AGREGAR BACKEND CON EXPIRACIÓN EN MINUTOS ============
add_backend_minutes() {
    clear
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
    
    # Calcular fecha de expiración
    local exp_date=$(date -d "+${minutes} minutes" '+%d/%m/%Y %H:%M')
    local block_comment="# BACKEND ${bname} - Creado: $(date '+%d/%m/%Y %H:%M') - Expira: ${exp_date}"
    
    # Insertar en configuración de nginx
    sed -i "/# SOPORTE PARA USUARIOS PERSONALIZADOS/i \ \n    ${block_comment}\n    if (\$http_backend = \"$bname\") {\n        set \$target_backend \"http://${bip}:${bport}\";\n    }" "$BACKEND_CONF"
    
    # Guardar datos de expiración (timestamp en segundos)
    local now=$(date +%s)
    local expiration_date=$((now + (minutes * 60)))
    echo "${bname}:${bip}:${bport}:${expiration_date}" >> "$USER_DATA"
    
    msg -verd "✅ BACKEND ${bname} agregado correctamente!"
    msg -info "IP: ${bip}:${bport} - Expira: ${exp_date} (${minutes} minutos)"
    
    # Recargar nginx
    if /usr/sbin/nginx -t; then
        systemctl reload nginx
        msg -verd "Configuración recargada!"
    fi
    
    msg -bar
    read -p "Presiona ENTER para continuar..."
}

# ============ AGREGAR BACKEND CON EXPIRACIÓN EN DÍAS ============
add_backend_days() {
    clear
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

# ============ VERIFICAR Y CREAR DIRECTORIOS ============
init_system() {
    mkdir -p "$BACKUP_DIR"
    touch "$USER_DATA"
    
    if ! command -v nginx &> /dev/null; then
        msg -ama "NGINX no está instalado. Usa opción 1 para instalar."
    fi
}

# ============ FUNCIÓN DE BACKUP ============
backup_backends() {
    show_banner
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

# ============ FUNCIÓN DE RESTAURACIÓN ============
restore_backends() {
    show_banner
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

# ============ LISTAR BACKUPS ============
list_backups() {
    show_banner
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

# ============ ELIMINAR BACKUPS ANTIGUOS ============
clean_old_backups() {
    show_banner
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

# ============ MENÚ DE BACKUPS ============
backup_menu() {
    while true; do
        show_banner
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

# ============ INSTALACIÓN PROFESIONAL DE NGINX ============
install_nginx_super() {
    show_banner
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
    
    cat > "$BACKEND_CONF" <<'EOF'
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
EOF

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

# ============ PROXY PYTHON PROFESIONAL ============
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

# ============ GESTIÓN DE BACKENDS PERSONALIZADOS ============
manage_backends() {
    show_banner
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
    
    # Mostrar backends del sistema fijos
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
            # ELIMINAR BACKEND
            read -p "Nombre del backend a eliminar: " bname
            
            msg -verm "⚠️  ¿ESTÁS SEGURO DE ELIMINAR ${bname}? (s/n): "
            read confirm
            if [[ "$confirm" =~ ^[sS]$ ]]; then
                # Eliminar del archivo de datos
                if [ -f "$USER_DATA" ]; then
                    grep -v "^${bname}:" "$USER_DATA" > /tmp/user_data_new
                    mv /tmp/user_data_new "$USER_DATA"
                fi
                
                # Eliminar de la configuración de NGINX
                if [ -f "$BACKEND_CONF" ]; then
                    grep -v "# BACKEND ${bname}" "$BACKEND_CONF" | grep -v "if (\\$http_backend = \"$bname\")" > /tmp/nginx_conf_new
                    mv /tmp/nginx_conf_new "$BACKEND_CONF"
                fi
                
                # Recargar nginx
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

# ============ MOSTRAR INSTRUCCIONES ÉPICAS ============
show_epic_instructions() {
    show_banner
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

# ============ VER ESTADO DEL SISTEMA ============
show_status() {
    show_banner
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

# ============ DESINSTALAR ============
uninstall_everything() {
    show_banner
    msg -tit "DESINSTALACIÓN COMPLETA"
    msg -verm "⚠️  ESTO ELIMINARÁ TODOS LOS COMPONENTES ⚠️"
    msg -bar
    
    read -p "¿ESTÁS SEGURO? (escribe 'SI' para confirmar): " confirm
    
    if [ "$confirm" = "SI" ]; then
        msg -info "Deteniendo servicios..."
        systemctl stop superc4mpeon-proxy nginx
        systemctl disable superc4mpeon-proxy nginx
        
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

# ============ MENÚ PRINCIPAL ============
main_menu() {
    while true; do
        show_banner
        
        if systemctl is-active --quiet nginx; then
            echo -e "${VERDE}⚡ NGINX: ACTIVO${SEMCOR}     ${CIAN}⚡ PUERTO: 80${SEMCOR}"
        else
            echo -e "${ROJO}⚡ NGINX: INACTIVO${SEMCOR}"
        fi
        
        echo -e "${MORADO}════════════════════════════════════════════════════════${SEMCOR}"
        echo -e "${VERDE}  [1]${SEMCOR} ${BLANCO}INSTALAR NGINX (80)${SEMCOR}"
        echo -e "${VERDE}  [2]${SEMCOR} ${BLANCO}INSTALAR PROXY PYTHON (PUERTO 8080)${SEMCOR}"
        echo -e "${VERDE}  [3]${SEMCOR} ${BLANCO}GESTIONAR BACKENDS PERSONALIZADOS${SEMCOR}"
        echo -e "${VERDE}  [4]${SEMCOR} ${BLANCO}VER ESTADO DEL SISTEMA${SEMCOR}"
        echo -e "${VERDE}  [5]${SEMCOR} ${BLANCO}INSTRUCCIONES Y PAYLOADS${SEMCOR}"
        echo -e "${VERDE}  [6]${SEMCOR} ${BLANCO}EDITAR CONFIGURACIÓN MANUAL${SEMCOR}"
        echo -e "${VERDE}  [7]${SEMCOR} ${BLANCO}REINICIAR SERVICIOS${SEMCOR}"
        echo -e "${VERDE}  [8]${SEMCOR} ${BLANCO}GESTIÓN DE BACKUPS${SEMCOR}"
        echo -e "${VERDE}  [9]${SEMCOR} ${BLANCO}LIMPIAR BACKENDS EXPIRADOS${SEMCOR}"
        echo -e "${VERDE} [10]${SEMCOR} ${BLANCO}📊 MONITOR DE RECURSOS${SEMCOR}"
        echo -e "${VERDE} [11]${SEMCOR} ${BLANCO}📈 MONITOR EN TIEMPO REAL (CTRL+C)${SEMCOR}"
        echo -e "${VERDE} [12]${SEMCOR} ${ROJO}DESINSTALAR TODO${SEMCOR}"
        echo -e "${VERDE} [13]${SEMCOR} ${BLANCO}SALIR${SEMCOR}"
        echo -e "${MORADO}════════════════════════════════════════════════════════${SEMCOR}"
        
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
            10) show_resource_monitor ;;
            11) show_realtime_monitor ;;
            12) uninstall_everything ;;
            13) 
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
