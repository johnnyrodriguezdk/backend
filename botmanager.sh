#!/bin/bash
# ============================================================
# INSTALADOR COMPLETO DEL BOT DE TELEGRAM (VERSIÓN FINAL)
# Con todas las mejoras y correcciones de errores comunes
# ============================================================

# Configuración de la barra de progreso
total_pasos=14
paso_actual=0

# Función para mostrar barra de progreso
progress_bar() {
    paso_actual=$((paso_actual + 1))
    porcentaje=$((paso_actual * 100 / total_pasos))
    barra=""
    for ((i=0; i<porcentaje/2; i++)); do barra="${barra}█"; done
    for ((i=porcentaje/2; i<50; i++)); do barra="${barra}░"; done
    echo -ne "\r\033[K[${barra}] ${porcentaje}% - $1"
}

# Verificar root
if [[ $EUID -ne 0 ]]; then
    echo "❌ Este script debe ejecutarse como root"
    exit 1
fi

clear
echo "╔════════════════════════════════════════════════════════╗"
echo "║   INSTALADOR DEL BOT DE TELEGRAM - BACKEND MANAGER    ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Solicitar datos (necesarios para la configuración)
read -p "👉 Token del bot (de @BotFather): " BOT_TOKEN
read -p "👉 Tu Chat ID (de @userinfobot): " CHAT_ID
echo ""

progress_bar "Actualizando repositorios..."
apt update -y >/dev/null 2>&1

progress_bar "Instalando dependencias del sistema..."
apt install -y python3 python3-pip python3-venv git curl wget bc >/dev/null 2>&1

# Crear directorio del bot
BOT_DIR="/opt/backend_bot"
mkdir -p $BOT_DIR
cd $BOT_DIR

progress_bar "Configurando entorno virtual Python..."
python3 -m venv venv >/dev/null 2>&1
source venv/bin/activate

progress_bar "Instalando librerías Python necesarias..."
pip install --upgrade pip >/dev/null 2>&1
pip install python-telegram-bot==13.15 psutil requests matplotlib dropbox schedule >/dev/null 2>&1

# Crear el script del bot con todas las funcionalidades
progress_bar "Generando código del bot..."
cat > bot.py <<'PYEOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import subprocess
import threading
import time
import logging
import io
import shutil
import schedule
from datetime import datetime

import psutil
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup, BotCommand, MenuButtonCommands
from telegram.ext import Updater, CommandHandler, CallbackQueryHandler, CallbackContext

# ============ CONFIGURACIÓN ============
TOKEN = os.environ.get('BOT_TOKEN', '')
ADMIN_CHAT_ID = os.environ.get('CHAT_ID', '')
MONITOR_INTERVAL = 1800  # 30 minutos para notificaciones periódicas
CPU_LIMIT = 80
RAM_LIMIT = 80
DISK_LIMIT = 80
SERVICES = ["nginx"]
USER_DATA = "/etc/nginx/superc4mpeon_users.txt"
BACKUP_DIR = "/root/superc4mpeon_backups"

# Logging silencioso (solo errores)
logging.basicConfig(level=logging.ERROR)
logger = logging.getLogger(__name__)

# Variables globales
last_alert = {}
updater = None

# ============ FUNCIONES AUXILIARES ============
def format_bytes(bytes):
    """Formatea bytes a TB/GB/MB"""
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if bytes < 1024.0:
            return f"{bytes:.2f} {unit}"
        bytes /= 1024.0
    return f"{bytes:.2f} PB"

def get_system_info():
    """Obtiene información del sistema"""
    info = {}
    # CPU
    info['cpu_percent'] = psutil.cpu_percent(interval=1)
    info['cpu_count'] = psutil.cpu_count()
    # RAM
    mem = psutil.virtual_memory()
    info['ram_total'] = mem.total
    info['ram_used'] = mem.used
    info['ram_percent'] = mem.percent
    # Disco
    disk = psutil.disk_usage('/')
    info['disk_total'] = disk.total
    info['disk_used'] = disk.used
    info['disk_percent'] = disk.percent
    # Red
    net = psutil.net_io_counters()
    info['net_sent'] = net.bytes_sent
    info['net_recv'] = net.bytes_recv
    # Servicios
    info['services'] = {}
    for svc in SERVICES:
        status = subprocess.run(['systemctl', 'is-active', svc], capture_output=True, text=True)
        info['services'][svc] = status.stdout.strip()
    return info

def get_backends():
    """Lee el archivo de backends"""
    backends = []
    if os.path.exists(USER_DATA):
        with open(USER_DATA, 'r') as f:
            for line in f:
                parts = line.strip().split(':')
                if len(parts) >= 4:
                    name, ip, port, exp = parts[0], parts[1], parts[2], parts[3]
                    backends.append({'name': name, 'ip': ip, 'port': port, 'exp': exp})
    return backends

def generate_usage_graph():
    """Genera un gráfico de uso"""
    try:
        cpu_hist = []
        ram_hist = []
        disk_hist = []
        timestamps = []
        for i in range(10):
            cpu_hist.append(psutil.cpu_percent(interval=0.1))
            mem = psutil.virtual_memory()
            ram_hist.append(mem.percent)
            disk = psutil.disk_usage('/')
            disk_hist.append(disk.percent)
            timestamps.append(datetime.now().strftime('%H:%M:%S'))
            time.sleep(0.2)
        
        fig, ax = plt.subplots(figsize=(10, 6))
        ax.plot(timestamps, cpu_hist, label='CPU', marker='o', color='red')
        ax.plot(timestamps, ram_hist, label='RAM', marker='s', color='blue')
        ax.plot(timestamps, disk_hist, label='Disco', marker='^', color='green')
        ax.set_xlabel('Tiempo')
        ax.set_ylabel('Uso (%)')
        ax.set_title('Uso de recursos')
        ax.legend()
        ax.grid(True)
        plt.xticks(rotation=45)
        plt.tight_layout()
        
        buf = io.BytesIO()
        plt.savefig(buf, format='png')
        buf.seek(0)
        plt.close()
        return buf
    except Exception as e:
        logger.error(f"Error en gráfico: {e}")
        return None

def send_notification(message):
    """Envía notificación al administrador"""
    try:
        updater.bot.send_message(chat_id=ADMIN_CHAT_ID, text=message, parse_mode='Markdown')
    except Exception as e:
        logger.error(f"Error enviando notificación: {e}")

def periodic_status():
    """Envía estado cada 30 minutos"""
    info = get_system_info()
    message = (
        f"*📊 Estado del servidor* ({datetime.now().strftime('%d/%m/%Y %H:%M')})\n"
        f"CPU: {info['cpu_percent']}%\n"
        f"RAM: {info['ram_percent']}% ({format_bytes(info['ram_used'])} / {format_bytes(info['ram_total'])})\n"
        f"Disco: {info['disk_percent']}% ({format_bytes(info['disk_used'])} / {format_bytes(info['disk_total'])})\n"
        f"Red (desde boot): 📥 {format_bytes(info['net_recv'])} | 📤 {format_bytes(info['net_sent'])}"
    )
    send_notification(message)

def monitor_task():
    """Tarea de monitoreo en segundo plano"""
    global last_alert
    schedule.every(30).minutes.do(periodic_status)
    
    while True:
        try:
            schedule.run_pending()
            info = get_system_info()
            alerts = []
            now = time.time()

            if info['cpu_percent'] > CPU_LIMIT and ('cpu' not in last_alert or (now - last_alert['cpu']) > 3600):
                alerts.append(f"⚠️ *CPU alto*: {info['cpu_percent']}%")
                last_alert['cpu'] = now
            if info['ram_percent'] > RAM_LIMIT and ('ram' not in last_alert or (now - last_alert['ram']) > 3600):
                alerts.append(f"⚠️ *RAM alto*: {info['ram_percent']}%")
                last_alert['ram'] = now
            if info['disk_percent'] > DISK_LIMIT and ('disk' not in last_alert or (now - last_alert['disk']) > 3600):
                alerts.append(f"⚠️ *Disco alto*: {info['disk_percent']}%")
                last_alert['disk'] = now

            # Servicios caídos
            for svc, status in info['services'].items():
                if status != 'active' and (svc not in last_alert or (now - last_alert[svc]) > 3600):
                    alerts.append(f"🔴 *Servicio caído*: {svc}")
                    last_alert[svc] = now

            if alerts:
                send_notification("\n".join(alerts))
        except Exception as e:
            logger.error(f"Error en monitor: {e}")
        time.sleep(60)

# ============ HANDLERS DEL BOT ============
def start(update: Update, context: CallbackContext):
    keyboard = [
        [InlineKeyboardButton("📊 Estado del sistema", callback_data='status')],
        [InlineKeyboardButton("📈 Gráfico de uso", callback_data='graph')],
        [InlineKeyboardButton("📋 Listar backends", callback_data='list_backends')],
        [InlineKeyboardButton("➕ Agregar backend", callback_data='add_backend')],
        [InlineKeyboardButton("❌ Eliminar backend", callback_data='delete_backend')],
        [InlineKeyboardButton("🔍 Healthcheck", callback_data='healthcheck')],
        [InlineKeyboardButton("📜 Logs de nginx", callback_data='logs')],
        [InlineKeyboardButton("⚙️ Servicios", callback_data='services')],
        [InlineKeyboardButton("🔄 Reiniciar bot", callback_data='restart')],
        [InlineKeyboardButton("❓ Ayuda", callback_data='help')]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    update.message.reply_text("🤖 *Backend Manager Bot*\n\nElige una opción:", reply_markup=reply_markup, parse_mode='Markdown')

def button_handler(update: Update, context: CallbackContext):
    query = update.callback_query
    query.answer()

    if query.data == 'status':
        info = get_system_info()
        text = (
            f"*📊 Estado*\n"
            f"CPU: {info['cpu_percent']}% ({info['cpu_count']} cores)\n"
            f"RAM: {info['ram_percent']}% ({format_bytes(info['ram_used'])} / {format_bytes(info['ram_total'])})\n"
            f"Disco: {info['disk_percent']}% ({format_bytes(info['disk_used'])} / {format_bytes(info['disk_total'])})\n"
            f"Red: 📥 {format_bytes(info['net_recv'])} | 📤 {format_bytes(info['net_sent'])}"
        )
        query.edit_message_text(text, parse_mode='Markdown')

    elif query.data == 'graph':
        query.edit_message_text("🔄 Generando gráfico, espera...")
        buf = generate_usage_graph()
        if buf:
            context.bot.send_photo(chat_id=query.message.chat_id, photo=buf, caption="📈 Uso de recursos")
            query.delete_message()
        else:
            query.edit_message_text("❌ No se pudo generar el gráfico.")

    elif query.data == 'list_backends':
        backends = get_backends()
        if not backends:
            text = "📭 No hay backends configurados."
        else:
            text = "*📋 Backends*\n\n"
            for b in backends:
                exp_date = "Sin expiración"
                if b['exp'] != '0':
                    try:
                        exp_date = time.strftime('%d/%m/%Y %H:%M', time.localtime(int(b['exp'])))
                    except:
                        exp_date = b['exp']
                text += f"• *{b['name']}*: `{b['ip']}:{b['port']}` ({exp_date})\n"
        query.edit_message_text(text, parse_mode='Markdown')

    elif query.data == 'add_backend':
        query.edit_message_text("Para agregar un backend, usa el comando:\n`/add nombre IP puerto días`\nEjemplo: `/add server1 192.168.1.100 80 30`", parse_mode='Markdown')

    elif query.data == 'delete_backend':
        backends = get_backends()
        if not backends:
            query.edit_message_text("📭 No hay backends para eliminar.")
            return
        keyboard = []
        for b in backends:
            keyboard.append([InlineKeyboardButton(f"❌ {b['name']} ({b['ip']}:{b['port']})", callback_data=f'del_{b["name"]}')])
        keyboard.append([InlineKeyboardButton("🔙 Cancelar", callback_data='back')])
        reply_markup = InlineKeyboardMarkup(keyboard)
        query.edit_message_text("Selecciona el backend a eliminar:", reply_markup=reply_markup)

    elif query.data.startswith('del_'):
        name = query.data[4:]
        if os.path.exists(USER_DATA):
            with open(USER_DATA, 'r') as f:
                lines = f.readlines()
            with open(USER_DATA, 'w') as f:
                for line in lines:
                    if not line.startswith(f"{name}:"):
                        f.write(line)
        subprocess.run(['/usr/sbin/nginx', '-t'], capture_output=True)
        subprocess.run(['systemctl', 'reload', 'nginx'], capture_output=True)
        send_notification(f"🗑️ Backend *{name}* eliminado por el administrador.")
        query.edit_message_text(f"✅ Backend *{name}* eliminado.", parse_mode='Markdown')
        time.sleep(2)
        # Volver al menú principal
        start(update, context)

    elif query.data == 'healthcheck':
        backends = get_backends()
        if not backends:
            query.edit_message_text("📭 No hay backends para verificar.")
            return
        query.edit_message_text("🔍 Ejecutando healthcheck, espera...")
        results = []
        for b in backends:
            cmd = ['curl', '-s', '--connect-timeout', '2', '--max-time', '3', f"http://{b['ip']}:{b['port']}"]
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode == 0:
                lat_cmd = ['curl', '-o', '/dev/null', '-s', '-w', '%{time_total}', '--connect-timeout', '2', '--max-time', '3', f"http://{b['ip']}:{b['port']}"]
                lat = subprocess.run(lat_cmd, capture_output=True, text=True).stdout
                results.append(f"✅ *{b['name']}*: OK ({lat}s)")
            else:
                results.append(f"❌ *{b['name']}*: FALLÓ")
        text = "*🔍 Healthcheck*\n\n" + "\n".join(results)
        query.edit_message_text(text, parse_mode='Markdown')

    elif query.data == 'logs':
        try:
            logs = subprocess.run(['tail', '-n', '20', '/var/log/nginx/access.log'], capture_output=True, text=True).stdout
            if not logs:
                logs = "No hay logs disponibles."
            query.edit_message_text(f"*📜 Últimos logs de nginx*\n```\n{logs}\n```", parse_mode='Markdown')
        except Exception as e:
            query.edit_message_text(f"❌ Error al obtener logs: {e}")

    elif query.data == 'services':
        info = get_system_info()
        keyboard = []
        for svc in SERVICES:
            status = info['services'][svc]
            emoji = '✅' if status == 'active' else '❌'
            keyboard.append([InlineKeyboardButton(f"{emoji} {svc}", callback_data=f'service_{svc}')])
        keyboard.append([InlineKeyboardButton("🔙 Volver", callback_data='back')])
        reply_markup = InlineKeyboardMarkup(keyboard)
        query.edit_message_text("Selecciona un servicio:", reply_markup=reply_markup)

    elif query.data.startswith('service_'):
        svc = query.data[8:]
        keyboard = [
            [InlineKeyboardButton("▶️ Iniciar", callback_data=f'start_{svc}')],
            [InlineKeyboardButton("⏹️ Detener", callback_data=f'stop_{svc}')],
            [InlineKeyboardButton("🔄 Reiniciar", callback_data=f'restart_{svc}')],
            [InlineKeyboardButton("🔙 Volver", callback_data='services')]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        query.edit_message_text(f"Gestionar: *{svc}*", reply_markup=reply_markup, parse_mode='Markdown')

    elif query.data.startswith(('start_', 'stop_', 'restart_')):
        action, svc = query.data.split('_', 1)
        subprocess.run(['systemctl', action, svc], capture_output=True)
        query.edit_message_text(f"✅ Comando `{action}` ejecutado en {svc}.", parse_mode='Markdown')
        time.sleep(2)
        # Volver al menú de servicios
        info = get_system_info()
        keyboard = []
        for s in SERVICES:
            status = info['services'][s]
            emoji = '✅' if status == 'active' else '❌'
            keyboard.append([InlineKeyboardButton(f"{emoji} {s}", callback_data=f'service_{s}')])
        keyboard.append([InlineKeyboardButton("🔙 Volver", callback_data='back')])
        reply_markup = InlineKeyboardMarkup(keyboard)
        query.message.edit_text("Selecciona un servicio:", reply_markup=reply_markup)

    elif query.data == 'restart':
        query.edit_message_text("♻️ Reiniciando el bot...")
        os.execl(sys.executable, sys.executable, *sys.argv)

    elif query.data == 'help':
        text = (
            "*🤖 Ayuda del Bot*\n\n"
            "• Usa los botones para navegar.\n"
            "• El monitor envía alertas automáticas si algo supera los límites.\n"
            "• Comandos disponibles:\n"
            "  /start - Mostrar menú\n"
            "  /add nombre IP puerto días - Agregar backend\n"
            "  /help - Esta ayuda\n\n"
            "Para más información, contacta al administrador."
        )
        query.edit_message_text(text, parse_mode='Markdown')

    elif query.data == 'back':
        start(update, context)

def add_command(update: Update, context: CallbackContext):
    try:
        args = context.args
        if len(args) < 3:
            update.message.reply_text("Uso: /add nombre IP puerto [días]\nEjemplo: /add server1 192.168.1.100 80 30")
            return
        name = args[0].lower()
        ip = args[1]
        port = args[2]
        days = int(args[3]) if len(args) > 3 else 0

        if days < 0:
            update.message.reply_text("❌ Los días deben ser 0 o positivo.")
            return

        exp = int(time.time()) + (days * 86400) if days > 0 else 0

        with open(USER_DATA, 'a') as f:
            f.write(f"{name}:{ip}:{port}:{exp}\n")

        subprocess.run(['/usr/sbin/nginx', '-t'], capture_output=True)
        subprocess.run(['systemctl', 'reload', 'nginx'], capture_output=True)

        send_notification(f"➕ Nuevo backend agregado: *{name}* ({ip}:{port}, {days} días)")
        update.message.reply_text(f"✅ Backend *{name}* agregado correctamente.", parse_mode='Markdown')
    except Exception as e:
        update.message.reply_text(f"❌ Error: {e}")

def post_init(updater):
    commands = [
        BotCommand("start", "Menú principal"),
        BotCommand("add", "Agregar backend (nombre IP puerto días)"),
        BotCommand("help", "Ayuda")
    ]
    updater.bot.set_my_commands(commands)
    updater.bot.set_chat_menu_button(menu_button=MenuButtonCommands())

def error_handler(update: Update, context: CallbackContext):
    logger.error(f"Error: {context.error}")

def main():
    global updater
    updater = Updater(TOKEN, use_context=True)
    dp = updater.dispatcher
    dp.add_handler(CommandHandler("start", start))
    dp.add_handler(CommandHandler("add", add_command))
    dp.add_handler(CommandHandler("help", lambda u,c: help_command(u,c)))
    dp.add_handler(CallbackQueryHandler(button_handler))
    dp.add_error_handler(error_handler)
    updater.post_init = post_init

    # Iniciar monitor en segundo plano
    monitor_thread = threading.Thread(target=monitor_task, daemon=True)
    monitor_thread.start()

    updater.start_polling()
    logger.info("Bot iniciado")
    updater.idle()

def help_command(update: Update, context: CallbackContext):
    text = (
        "*🤖 Ayuda del Bot*\n\n"
        "• Usa los botones para navegar.\n"
        "• El monitor envía alertas automáticas si algo supera los límites.\n"
        "• Comandos disponibles:\n"
        "  /start - Mostrar menú\n"
        "  /add nombre IP puerto días - Agregar backend\n"
        "  /help - Esta ayuda\n\n"
        "Para más información, contacta al administrador."
    )
    if update.callback_query:
        update.callback_query.edit_message_text(text, parse_mode='Markdown')
    else:
        update.message.reply_text(text, parse_mode='Markdown')

if __name__ == '__main__':
    main()
PYEOF

# Crear archivo de entorno con los datos proporcionados
progress_bar "Guardando configuración..."
cat > /etc/default/backend_bot <<EOF
BOT_TOKEN=$BOT_TOKEN
CHAT_ID=$CHAT_ID
EOF

# Crear servicio systemd
progress_bar "Creando servicio systemd..."
cat > /etc/systemd/system/backend_bot.service <<EOF
[Unit]
Description=Backend Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$BOT_DIR
EnvironmentFile=/etc/default/backend_bot
ExecStart=$BOT_DIR/venv/bin/python $BOT_DIR/bot.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Recargar systemd y habilitar servicio
progress_bar "Configurando inicio automático..."
systemctl daemon-reload >/dev/null 2>&1
systemctl enable backend_bot.service >/dev/null 2>&1

# Iniciar el bot
progress_bar "Iniciando el bot..."
systemctl start backend_bot.service >/dev/null 2>&1

# Verificar que el bot esté funcionando
sleep 2
if systemctl is-active --quiet backend_bot.service; then
    progress_bar "Verificando funcionamiento..."
    # Pequeña espera para asegurar
    sleep 1
    echo -e "\r\033[K[██████████████████████████████████████████████████] 100% - ¡COMPLETADO!"
else
    echo -e "\r\033[K[██████████████████████████████████████████████████] 100% - COMPLETADO CON ERRORES"
fi

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║   BOT INSTALADO CORRECTAMENTE                         ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "📱 Abre Telegram y envía /start a tu bot"
echo ""
echo "✅ Recibirás notificaciones automáticas cada 30 minutos con:"
echo "   - Estado de CPU, RAM, disco y tráfico de red (GB/TB)"
echo "✅ Botón de menú de comandos disponible en la parte inferior izquierda"
echo "✅ Gráficos de uso, gestión de backends, healthcheck y más"
echo ""
echo "🔧 Comandos útiles para administrar el bot:"
echo "   systemctl status backend_bot  - Ver estado del bot"
echo "   journalctl -u backend_bot -f  - Ver logs en tiempo real"
echo "   systemctl restart backend_bot - Reiniciar el bot"
echo ""
echo "📝 Archivos importantes:"
echo "   Configuración: /etc/default/backend_bot"
echo "   Código del bot: /opt/backend_bot/bot.py"
echo ""
