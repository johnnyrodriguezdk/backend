#!/bin/bash
# ============================================================
# INSTALADOR COMPLETO DEL BOT DE TELEGRAM (VERSIÓN CON DATOS AL FINAL)
# Con todas las mejoras y correcciones
# ============================================================

# Colores
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
echo -e "\E[41;1;37m   INSTALADOR DEL BOT DE TELEGRAM - BACKEND MANAGER   \E[0m"
echo -e "${CIAN}════════════════════════════════════════════════════════${SEMCOR}"

# Función para mostrar progreso
progress_bar() {
    local paso=$1
    local total=$2
    local mensaje=$3
    local porcentaje=$((paso * 100 / total))
    local barra=""
    for ((i=0; i<porcentaje/2; i++)); do barra="${barra}█"; done
    for ((i=porcentaje/2; i<50; i++)); do barra="${barra}░"; done
    echo -ne "\r\033[K[${barra}] ${porcentaje}% - ${mensaje}"
}

# Pasos totales
TOTAL_PASOS=10
paso=0

progress_bar $paso $TOTAL_PASOS "Actualizando repositorios..."
apt update -y >/dev/null 2>&1

paso=$((paso+1))
progress_bar $paso $TOTAL_PASOS "Instalando dependencias del sistema..."
apt install -y python3 python3-pip python3-venv git curl wget bc >/dev/null 2>&1

paso=$((paso+1))
progress_bar $paso $TOTAL_PASOS "Creando directorio del bot..."
BOT_DIR="/opt/backend_bot"
mkdir -p $BOT_DIR
cd $BOT_DIR

paso=$((paso+1))
progress_bar $paso $TOTAL_PASOS "Configurando entorno virtual Python..."
python3 -m venv venv >/dev/null 2>&1
source venv/bin/activate

paso=$((paso+1))
progress_bar $paso $TOTAL_PASOS "Instalando librerías Python..."
pip install --upgrade pip >/dev/null 2>&1
pip install python-telegram-bot==13.15 psutil requests matplotlib dropbox schedule >/dev/null 2>&1

paso=$((paso+1))
progress_bar $paso $TOTAL_PASOS "Generando código del bot..."
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
MONITOR_INTERVAL = 1800  # 30 minutos
CPU_LIMIT = 80
RAM_LIMIT = 80
DISK_LIMIT = 80
SERVICES = ["nginx"]
USER_DATA = "/etc/nginx/superc4mpeon_users.txt"
BACKUP_DIR = "/root/superc4mpeon_backups"

logging.basicConfig(level=logging.ERROR)
logger = logging.getLogger(__name__)

last_alert = {}
updater = None

def format_bytes(bytes):
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if bytes < 1024.0:
            return f"{bytes:.2f} {unit}"
        bytes /= 1024.0
    return f"{bytes:.2f} PB"

def get_system_info():
    info = {}
    info['cpu_percent'] = psutil.cpu_percent(interval=1)
    info['cpu_count'] = psutil.cpu_count()
    mem = psutil.virtual_memory()
    info['ram_total'] = mem.total
    info['ram_used'] = mem.used
    info['ram_percent'] = mem.percent
    disk = psutil.disk_usage('/')
    info['disk_total'] = disk.total
    info['disk_used'] = disk.used
    info['disk_percent'] = disk.percent
    net = psutil.net_io_counters()
    info['net_sent'] = net.bytes_sent
    info['net_recv'] = net.bytes_recv
    info['services'] = {}
    for svc in SERVICES:
        status = subprocess.run(['systemctl', 'is-active', svc], capture_output=True, text=True)
        info['services'][svc] = status.stdout.strip()
    return info

def get_backends():
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
        fig, ax = plt.subplots(figsize=(10,6))
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
    except:
        return None

def send_notification(message):
    try:
        updater.bot.send_message(chat_id=ADMIN_CHAT_ID, text=message, parse_mode='Markdown')
    except:
        pass

def periodic_status():
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
    global last_alert
    schedule.every(30).minutes.do(periodic_status)
    while True:
        try:
            schedule.run_pending()
            info = get_system_info()
            alerts = []
            now = time.time()
            if info['cpu_percent'] > CPU_LIMIT and ('cpu' not in last_alert or now - last_alert['cpu'] > 3600):
                alerts.append(f"⚠️ *CPU alto*: {info['cpu_percent']}%")
                last_alert['cpu'] = now
            if info['ram_percent'] > RAM_LIMIT and ('ram' not in last_alert or now - last_alert['ram'] > 3600):
                alerts.append(f"⚠️ *RAM alto*: {info['ram_percent']}%")
                last_alert['ram'] = now
            if info['disk_percent'] > DISK_LIMIT and ('disk' not in last_alert or now - last_alert['disk'] > 3600):
                alerts.append(f"⚠️ *Disco alto*: {info['disk_percent']}%")
                last_alert['disk'] = now
            for svc, status in info['services'].items():
                if status != 'active' and (svc not in last_alert or now - last_alert[svc] > 3600):
                    alerts.append(f"🔴 *Servicio caído*: {svc}")
                    last_alert[svc] = now
            if alerts:
                send_notification("\n".join(alerts))
        except:
            pass
        time.sleep(60)

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
        text = f"*📊 Estado*\nCPU: {info['cpu_percent']}% ({info['cpu_count']} cores)\nRAM: {info['ram_percent']}% ({format_bytes(info['ram_used'])} / {format_bytes(info['ram_total'])})\nDisco: {info['disk_percent']}% ({format_bytes(info['disk_used'])} / {format_bytes(info['disk_total'])})\nRed: 📥 {format_bytes(info['net_recv'])} | 📤 {format_bytes(info['net_sent'])}"
        query.edit_message_text(text, parse_mode='Markdown')
    elif query.data == 'graph':
        query.edit_message_text("🔄 Generando...")
        buf = generate_usage_graph()
        if buf:
            context.bot.send_photo(chat_id=query.message.chat_id, photo=buf, caption="📈 Uso de recursos")
            query.delete_message()
        else:
            query.edit_message_text("❌ Error")
    elif query.data == 'list_backends':
        backends = get_backends()
        if not backends:
            text = "📭 No hay backends"
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
        query.edit_message_text("Usa: `/add nombre IP puerto días`", parse_mode='Markdown')
    elif query.data == 'delete_backend':
        backends = get_backends()
        if not backends:
            query.edit_message_text("📭 No hay backends")
            return
        keyboard = []
        for b in backends:
            keyboard.append([InlineKeyboardButton(f"❌ {b['name']} ({b['ip']}:{b['port']})", callback_data=f'del_{b["name"]}')])
        keyboard.append([InlineKeyboardButton("🔙 Cancelar", callback_data='back')])
        query.edit_message_text("Selecciona:", reply_markup=InlineKeyboardMarkup(keyboard))
    elif query.data.startswith('del_'):
        name = query.data[4:]
        if os.path.exists(USER_DATA):
            with open(USER_DATA, 'r') as f:
                lines = f.readlines()
            with open(USER_DATA, 'w') as f:
                for line in lines:
                    if not line.startswith(f"{name}:"):
                        f.write(line)
        subprocess.run(['systemctl', 'reload', 'nginx'], capture_output=True)
        send_notification(f"🗑️ Backend *{name}* eliminado")
        query.edit_message_text(f"✅ Backend *{name}* eliminado", parse_mode='Markdown')
        time.sleep(2)
        start(update, context)
    elif query.data == 'healthcheck':
        backends = get_backends()
        if not backends:
            query.edit_message_text("📭 No hay backends")
            return
        query.edit_message_text("🔍 Verificando...")
        results = []
        for b in backends:
            cmd = ['curl', '-s', '--connect-timeout', '2', '--max-time', '3', f"http://{b['ip']}:{b['port']}"]
            if subprocess.run(cmd, capture_output=True).returncode == 0:
                lat = subprocess.run(['curl', '-o', '/dev/null', '-s', '-w', '%{time_total}', '--connect-timeout', '2', '--max-time', '3', f"http://{b['ip']}:{b['port']}"], capture_output=True, text=True).stdout
                results.append(f"✅ *{b['name']}*: OK ({lat}s)")
            else:
                results.append(f"❌ *{b['name']}*: FALLÓ")
        query.edit_message_text("*🔍 Healthcheck*\n\n" + "\n".join(results), parse_mode='Markdown')
    elif query.data == 'logs':
        try:
            logs = subprocess.run(['tail', '-n', '20', '/var/log/nginx/access.log'], capture_output=True, text=True).stdout
            query.edit_message_text(f"*📜 Logs*\n```\n{logs}\n```", parse_mode='Markdown')
        except:
            query.edit_message_text("❌ Error")
    elif query.data == 'services':
        info = get_system_info()
        keyboard = []
        for svc in SERVICES:
            status = info['services'][svc]
            emoji = '✅' if status == 'active' else '❌'
            keyboard.append([InlineKeyboardButton(f"{emoji} {svc}", callback_data=f'service_{svc}')])
        keyboard.append([InlineKeyboardButton("🔙 Volver", callback_data='back')])
        query.edit_message_text("Servicios:", reply_markup=InlineKeyboardMarkup(keyboard))
    elif query.data.startswith('service_'):
        svc = query.data[8:]
        keyboard = [
            [InlineKeyboardButton("▶️ Iniciar", callback_data=f'start_{svc}')],
            [InlineKeyboardButton("⏹️ Detener", callback_data=f'stop_{svc}')],
            [InlineKeyboardButton("🔄 Reiniciar", callback_data=f'restart_{svc}')],
            [InlineKeyboardButton("🔙 Volver", callback_data='services')]
        ]
        query.edit_message_text(f"*{svc}*", reply_markup=InlineKeyboardMarkup(keyboard), parse_mode='Markdown')
    elif query.data.startswith(('start_', 'stop_', 'restart_')):
        action, svc = query.data.split('_', 1)
        subprocess.run(['systemctl', action, svc], capture_output=True)
        query.edit_message_text(f"✅ {action} en {svc}")
        time.sleep(2)
        info = get_system_info()
        keyboard = []
        for s in SERVICES:
            status = info['services'][s]
            emoji = '✅' if status == 'active' else '❌'
            keyboard.append([InlineKeyboardButton(f"{emoji} {s}", callback_data=f'service_{s}')])
        keyboard.append([InlineKeyboardButton("🔙 Volver", callback_data='back')])
        query.message.edit_text("Servicios:", reply_markup=InlineKeyboardMarkup(keyboard))
    elif query.data == 'restart':
        query.edit_message_text("♻️ Reiniciando...")
        os.execl(sys.executable, sys.executable, *sys.argv)
    elif query.data == 'help':
        query.edit_message_text("*Ayuda*\n/start - Menú\n/add nombre IP puerto días - Agregar backend", parse_mode='Markdown')
    elif query.data == 'back':
        start(update, context)

def add_command(update: Update, context: CallbackContext):
    try:
        args = context.args
        if len(args) < 3:
            update.message.reply_text("Uso: /add nombre IP puerto [días]")
            return
        name = args[0].lower()
        ip = args[1]
        port = args[2]
        days = int(args[3]) if len(args) > 3 else 0
        exp = int(time.time()) + (days * 86400) if days > 0 else 0
        with open(USER_DATA, 'a') as f:
            f.write(f"{name}:{ip}:{port}:{exp}\n")
        subprocess.run(['systemctl', 'reload', 'nginx'], capture_output=True)
        send_notification(f"➕ Backend *{name}* agregado ({ip}:{port}, {days} días)")
        update.message.reply_text(f"✅ Backend {name} agregado")
    except:
        update.message.reply_text("❌ Error")

def post_init(updater):
    commands = [
        BotCommand("start", "Menú principal"),
        BotCommand("add", "Agregar backend"),
        BotCommand("help", "Ayuda")
    ]
    updater.bot.set_my_commands(commands)
    updater.bot.set_chat_menu_button(menu_button=MenuButtonCommands())

def main():
    global updater
    updater = Updater(TOKEN, use_context=True)
    dp = updater.dispatcher
    dp.add_handler(CommandHandler("start", start))
    dp.add_handler(CommandHandler("add", add_command))
    dp.add_handler(CommandHandler("help", lambda u,c: u.message.reply_text("Comandos: /start, /add")))
    dp.add_handler(CallbackQueryHandler(button_handler))
    updater.post_init = post_init
    threading.Thread(target=monitor_task, daemon=True).start()
    updater.start_polling()
    updater.idle()

if __name__ == '__main__':
    main()
PYEOF

paso=$((paso+1))
progress_bar $paso $TOTAL_PASOS "Instalación base completada."

# Ahora pedir los datos
echo -e "\n\n${CIAN}════════════════════════════════════════════════════════${SEMCOR}"
echo -e "${AMARILLO}Configuración final del bot${SEMCOR}"
echo -e "${CIAN}════════════════════════════════════════════════════════${SEMCOR}"
echo ""

while [ -z "$BOT_TOKEN" ]; do
    read -p "👉 Introduce el token de tu bot (de @BotFather): " BOT_TOKEN
done

while [ -z "$CHAT_ID" ]; do
    read -p "👉 Introduce tu Chat ID (de @userinfobot): " CHAT_ID
done

# Verificar token con curl
echo -ne "Verificando token..."
if curl -s "https://api.telegram.org/bot$BOT_TOKEN/getMe" | grep -q '"ok":true'; then
    echo -e " ${VERDE}✅ Válido${SEMCOR}"
else
    echo -e " ${ROJO}❌ Inválido. Por favor verifica el token.${SEMCOR}"
    exit 1
fi

paso=$((paso+1))
progress_bar $paso $TOTAL_PASOS "Guardando configuración..."
cat > /etc/default/backend_bot <<EOF
BOT_TOKEN=$BOT_TOKEN
CHAT_ID=$CHAT_ID
EOF

paso=$((paso+1))
progress_bar $paso $TOTAL_PASOS "Creando servicio systemd..."
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

paso=$((paso+1))
progress_bar $paso $TOTAL_PASOS "Habilitando e iniciando servicio..."
systemctl daemon-reload >/dev/null 2>&1
systemctl enable backend_bot.service >/dev/null 2>&1
systemctl start backend_bot.service >/dev/null 2>&1

# Verificar
if systemctl is-active --quiet backend_bot.service; then
    echo -e "\n\n${VERDE}✅ Bot instalado y funcionando correctamente.${SEMCOR}"
else
    echo -e "\n\n${ROJO}❌ El servicio no se inició. Revisa los logs con: journalctl -u backend_bot -f${SEMCOR}"
fi

echo ""
echo "📱 Envía /start a tu bot en Telegram para ver el menú."
echo "📊 Recibirás notificaciones automáticas cada 30 minutos."
echo ""
echo "🔧 Comandos útiles:"
echo "   systemctl status backend_bot  - Ver estado"
echo "   journalctl -u backend_bot -f  - Ver logs en tiempo real"
echo "   systemctl restart backend_bot - Reiniciar el bot"
echo ""
