#!/bin/bash
# ============================================================
# INSTALADOR EXTENDIDO - BACKEND MANAGER by JOHNNY
# Versión: 6.0 COMPLETA - 30 opciones + API + Dashboard
# ============================================================

VERDE='\e[1;32m'
ROJO='\e[1;31m'
AMARILLO='\e[1;33m'
AZUL='\e[1;34m'
MORADO='\e[1;35m'
CIAN='\e[1;36m'
BLANCO='\e[1;37m'
TURQUESA='\e[1;96m'
SEMCOR='\e[0m'

if [[ $EUID -ne 0 ]]; then
    echo -e "${ROJO}[✗] Ejecuta como root: sudo bash $0${SEMCOR}"
    exit 1
fi

echo -e "${CIAN}════════════════════════════════════════════════════════${SEMCOR}"
echo -e "\E[41;1;37m   INSTALADOR EXTENDIDO - BACKEND MANAGER by JOHNNY   \E[0m"
echo -e "${CIAN}════════════════════════════════════════════════════════${SEMCOR}"

# Backup del script actual si existe
if [ -f /root/superc4mpeon.sh ]; then
    echo -e "${AMARILLO}[!] El script actual será reemplazado. Se hará un backup.${SEMCOR}"
    cp /root/superc4mpeon.sh /root/superc4mpeon.sh.backup.$(date +%Y%m%d%H%M%S)
    echo -e "${VERDE}[✓] Backup creado.${SEMCOR}"
fi

# ============ DEPENDENCIAS ============
echo -e "${AMARILLO}[ℹ] Instalando dependencias...${SEMCOR}"
apt update -y
apt install -y nginx curl wget speedtest-cli ufw bc net-tools jq python3 python3-pip python3-venv
pip3 install --break-system-packages flask requests psutil flask-cors 2>/dev/null || pip3 install flask requests psutil flask-cors

# ============ ESTRUCTURA PARA DATOS JSON ============
echo -e "${AMARILLO}[ℹ] Creando estructura de datos JSON...${SEMCOR}"
BM_BASE="/etc/backend-manager"
BM_DATA="${BM_BASE}/data"
BM_WEB="/var/www/backend-manager"
BM_BACKUP="/root/backend-backups"

mkdir -p "${BM_BASE}" "${BM_DATA}" "${BM_WEB}" "${BM_BACKUP}"
chmod 755 "${BM_BASE}" "${BM_WEB}"
chmod 700 "${BM_DATA}"

# Crear archivos JSON iniciales
cat > "${BM_DATA}/users.json" << 'EOF'
[
  {
    "id": 1,
    "username": "admin",
    "password": "$2y$10$YourHashedPasswordHere",
    "backend": "local",
    "traffic_limit": 10737418240,
    "traffic_used": 0,
    "expiry": 1893456000,
    "status": "active",
    "created_at": "2024-01-01T00:00:00Z"
  }
]
EOF

cat > "${BM_DATA}/backends.json" << 'EOF'
[
  {
    "id": 1,
    "name": "local",
    "ip": "127.0.0.1",
    "port": 8080,
    "target": "127.0.0.1:8080",
    "type": "system",
    "status": "active",
    "created_at": "2024-01-01T00:00:00Z"
  },
  {
    "id": 2,
    "name": "ssh",
    "ip": "127.0.0.1",
    "port": 22,
    "target": "127.0.0.1:22",
    "type": "system",
    "status": "active",
    "created_at": "2024-01-01T00:00:00Z"
  }
]
EOF

cat > "${BM_DATA}/domains.json" << 'EOF'
[]
EOF

cat > "${BM_DATA}/traffic.json" << 'EOF'
{
  "daily": [],
  "monthly": [],
  "backends": {},
  "users": {},
  "total_rx": 0,
  "total_tx": 0,
  "last_updated": "2024-01-01T00:00:00Z"
}
EOF

cat > "${BM_DATA}/logs.json" << 'EOF'
[]
EOF

cat > "${BM_DATA}/settings.json" << 'EOF'
{
  "nginx_auto_reload": true,
  "backup_retention_days": 30,
  "default_expiry_days": 7,
  "panel_port": 8081,
  "ssl_enabled": false
}
EOF

chmod 644 "${BM_DATA}"/*.json
chmod 600 "${BM_DATA}/users.json"

# ============ API FLASK ============
echo -e "${AMARILLO}[ℹ] Configurando API Flask...${SEMCOR}"
cat > "${BM_BASE}/api_server.py" << 'EOF'
#!/usr/bin/env python3
from flask import Flask, jsonify
from flask_cors import CORS
import json
import os
import psutil
from datetime import datetime

app = Flask(__name__)
CORS(app)
DATA_DIR = "/etc/backend-manager/data"

def read_json(file):
    try:
        with open(os.path.join(DATA_DIR, file)) as f:
            return json.load(f)
    except:
        return {}

@app.route('/api/status')
def status():
    return jsonify({"status": "online", "time": datetime.now().isoformat()})

@app.route('/api/backends')
def backends():
    return jsonify(read_json("backends.json"))

@app.route('/api/users')
def users():
    data = read_json("users.json")
    if isinstance(data, list):
        for u in data:
            u.pop('password', None)
    return jsonify(data)

@app.route('/api/server')
def server():
    return jsonify({
        "cpu": psutil.cpu_percent(),
        "ram": psutil.virtual_memory().percent,
        "disk": psutil.disk_usage('/').percent,
        "uptime": int(datetime.now().timestamp() - psutil.boot_time())
    })

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5000)
EOF

chmod +x "${BM_BASE}/api_server.py"

# Servicio systemd para la API
cat > /etc/systemd/system/backend-manager-api.service << 'EOF'
[Unit]
Description=Backend Manager API
After=network.target

[Service]
ExecStart=/usr/bin/python3 /etc/backend-manager/api_server.py
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable backend-manager-api
systemctl restart backend-manager-api

# ============ NGINX PARA PANEL WEB (PUERTO 8081) ============
echo -e "${AMARILLO}[ℹ] Configurando Nginx para panel web...${SEMCOR}"
cat > /etc/nginx/sites-available/backend-panel << 'EOF'
server {
    listen 8081;
    listen [::]:8081;
    server_name _;
    root /var/www/backend-manager;
    index index.html;
    location / {
        try_files $uri $uri/ =404;
    }
    location /api/ {
        proxy_pass http://127.0.0.1:5000/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF
ln -sf /etc/nginx/sites-available/backend-panel /etc/nginx/sites-enabled/ 2>/dev/null
nginx -t && systemctl reload nginx

# ============ PANEL WEB BÁSICO ============
cat > /var/www/backend-manager/index.html << 'EOF'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Backend Manager Pro · Dashboard</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        :root {
            --bg-primary: #0f172a;
            --bg-secondary: #1e293b;
            --bg-card: #1e293b;
            --border-color: #334155;
            --text-primary: #f1f5f9;
            --text-secondary: #94a3b8;
            --accent-blue: #3b82f6;
            --accent-green: #10b981;
            --accent-yellow: #f59e0b;
            --accent-red: #ef4444;
            --accent-purple: #8b5cf6;
        }
        body {
            background-color: var(--bg-primary);
            color: var(--text-primary);
            font-family: 'Inter', system-ui, -apple-system, sans-serif;
        }
        .card {
            background-color: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 1rem;
            transition: all 0.2s;
        }
        .card:hover {
            border-color: var(--accent-blue);
            transform: translateY(-2px);
            box-shadow: 0 10px 25px -5px rgba(59, 130, 246, 0.3);
        }
        .nav-link {
            color: var(--text-secondary);
            transition: color 0.2s;
            font-weight: 500;
        }
        .nav-link:hover {
            color: var(--accent-blue);
        }
        .nav-link.active {
            color: var(--accent-blue);
            border-bottom: 2px solid var(--accent-blue);
        }
        .status-badge {
            display: inline-flex;
            align-items: center;
            padding: 0.25rem 0.75rem;
            border-radius: 9999px;
            font-size: 0.75rem;
            font-weight: 500;
        }
        .status-active {
            background-color: rgba(16, 185, 129, 0.2);
            color: #10b981;
        }
        .status-expired {
            background-color: rgba(239, 68, 68, 0.2);
            color: #ef4444;
        }
        .progress-bar {
            height: 0.5rem;
            background-color: #334155;
            border-radius: 9999px;
            overflow: hidden;
        }
        .progress-fill {
            height: 100%;
            border-radius: 9999px;
            transition: width 0.3s ease;
        }
        .progress-blue { background-color: var(--accent-blue); }
        .progress-green { background-color: var(--accent-green); }
        .progress-yellow { background-color: var(--accent-yellow); }
    </style>
</head>
<body class="p-4 md:p-6">
    <div class="max-w-7xl mx-auto">
        <!-- Header con navegación -->
        <div class="flex flex-wrap items-center justify-between mb-8">
            <div class="flex items-center gap-2">
                <i class="fas fa-bolt text-2xl text-blue-400"></i>
                <span class="text-xl font-bold bg-gradient-to-r from-blue-400 to-cyan-400 bg-clip-text text-transparent">Backend Manager Pro</span>
            </div>
            <div class="flex flex-wrap gap-4 text-sm mt-2 md:mt-0">
                <a href="#" class="nav-link active">Panel</a>
                <a href="#" class="nav-link">Servicios</a>
                <a href="#" class="nav-link">Comprar</a>
                <a href="#" class="nav-link">VPS</a>
                <a href="#" class="nav-link">Financiero</a>
                <a href="#" class="nav-link">Herramientas</a>
                <a href="#" class="nav-link">Academia</a>
                <a href="#" class="nav-link">Afiliados</a>
                <a href="#" class="nav-link"><i class="fas fa-search"></i></a>
                <a href="#" class="nav-link"><i class="fas fa-cog"></i></a>
            </div>
        </div>

        <!-- Tarjetas de resumen -->
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
            <div class="card p-5">
                <div class="flex items-center justify-between">
                    <div>
                        <p class="text-sm text-gray-400">Servicios Activos</p>
                        <p class="text-2xl font-bold" id="active-services">0</p>
                    </div>
                    <div class="w-10 h-10 bg-blue-500/20 rounded-lg flex items-center justify-center">
                        <i class="fas fa-cloud text-blue-400"></i>
                    </div>
                </div>
                <div class="mt-2 text-xs text-gray-500">CloudFront · <span id="active-domains">0</span> dominios</div>
            </div>
            <div class="card p-5">
                <div class="flex items-center justify-between">
                    <div>
                        <p class="text-sm text-gray-400">Total Afiliados</p>
                        <p class="text-2xl font-bold" id="total-affiliates">0</p>
                    </div>
                    <div class="w-10 h-10 bg-green-500/20 rounded-lg flex items-center justify-center">
                        <i class="fas fa-users text-green-400"></i>
                    </div>
                </div>
                <div class="mt-2 text-xs text-gray-500">Usuarios referidos</div>
            </div>
            <div class="card p-5">
                <div class="flex items-center justify-between">
                    <div>
                        <p class="text-sm text-gray-400">Tickets Abiertos</p>
                        <p class="text-2xl font-bold" id="open-tickets">0</p>
                    </div>
                    <div class="w-10 h-10 bg-yellow-500/20 rounded-lg flex items-center justify-center">
                        <i class="fas fa-ticket text-yellow-400"></i>
                    </div>
                </div>
                <div class="mt-2 text-xs text-gray-500">Soporte técnico</div>
            </div>
            <div class="card p-5">
                <div class="flex items-center justify-between">
                    <div>
                        <p class="text-sm text-gray-400">Notificaciones</p>
                        <p class="text-2xl font-bold" id="notifications">3</p>
                    </div>
                    <div class="w-10 h-10 bg-purple-500/20 rounded-lg flex items-center justify-center">
                        <i class="fas fa-bell text-purple-400"></i>
                    </div>
                </div>
                <div class="mt-2 text-xs text-gray-500">Alertas del sistema</div>
            </div>
        </div>

        <!-- Fila principal: Estado de servicios y gráficos -->
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
            <!-- Columna izquierda: Estado de servicios -->
            <div class="lg:col-span-1 space-y-6">
                <div class="card p-5">
                    <h3 class="font-semibold mb-4 flex items-center gap-2">
                        <i class="fas fa-chart-line text-blue-400"></i>
                        Status dos Servicios
                    </h3>
                    <div class="space-y-4">
                        <div>
                            <div class="flex justify-between text-sm mb-1">
                                <span>CloudFront</span>
                                <span class="text-gray-400" id="cloudfront-status">1/3 dominios</span>
                            </div>
                            <div class="progress-bar">
                                <div id="cloudfront-progress" class="progress-fill progress-blue" style="width: 33%"></div>
                            </div>
                        </div>
                        <div>
                            <div class="flex justify-between text-sm mb-1">
                                <span>Online</span>
                                <span class="text-gray-400" id="online-percent">98.8% uptime</span>
                            </div>
                            <div class="progress-bar">
                                <div id="online-progress" class="progress-fill progress-green" style="width: 98.8%"></div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Distribución de servicios (gráfico de pastel) -->
                <div class="card p-5">
                    <h3 class="font-semibold mb-4 flex items-center gap-2">
                        <i class="fas fa-chart-pie text-green-400"></i>
                        Distribución
                    </h3>
                    <canvas id="distributionChart" height="150"></canvas>
                    <div class="mt-4 text-sm text-center text-gray-400">Servicios por tipo</div>
                </div>

                <!-- Vencimientos próximos -->
                <div class="card p-5">
                    <h3 class="font-semibold mb-4 flex items-center gap-2">
                        <i class="fas fa-clock text-yellow-400"></i>
                        Vencimientos
                    </h3>
                    <div id="expiring-list" class="space-y-3">
                        <!-- Se llenará con JS -->
                    </div>
                </div>
            </div>

            <!-- Columna derecha: Gráfico de uptime 24h -->
            <div class="lg:col-span-2 card p-5">
                <h3 class="font-semibold mb-4 flex items-center gap-2">
                    <i class="fas fa-chart-bar text-blue-400"></i>
                    Uptime 24h
                </h3>
                <canvas id="uptimeChart" height="200"></canvas>
                <div class="mt-4 flex justify-between text-xs text-gray-500" id="uptime-labels">
                    <!-- Se llenará con JS -->
                </div>
            </div>
        </div>

        <!-- Sección de planes (Bronce, Plata, Oro, Platino) -->
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6 mb-6">
            <div class="card p-5 text-center">
                <h4 class="text-lg font-bold text-amber-600">Bronce</h4>
                <p class="text-2xl font-bold my-2">R$ 54,99 <span class="text-sm font-normal text-gray-400">/mes</span></p>
                <ul class="text-sm text-left space-y-2 my-4 text-gray-300">
                    <li><i class="fas fa-check text-green-400 mr-2"></i>Intel Xeon Gold 6138</li>
                    <li><i class="fas fa-check text-green-400 mr-2"></i>2GB RAM</li>
                    <li><i class="fas fa-check text-green-400 mr-2"></i>2 vCPU</li>
                    <li><i class="fas fa-check text-green-400 mr-2"></i>IP dedicada</li>
                    <li><i class="fas fa-check text-green-400 mr-2"></i>Uplink +1Gbps</li>
                    <li><i class="fas fa-check text-green-400 mr-2"></i>20GB SSD</li>
                </ul>
                <button class="w-full bg-blue-600 hover:bg-blue-700 text-white py-2 rounded-lg transition">Contratar Ahora</button>
            </div>
            <div class="card p-5 text-center">
                <h4 class="text-lg font-bold text-gray-400">Plata</h4>
                <p class="text-2xl font-bold my-2">R$ 74,99 <span class="text-sm font-normal text-gray-400">/mes</span></p>
                <ul class="text-sm text-left space-y-2 my-4 text-gray-300">
                    <li><i class="fas fa-check text-green-400 mr-2"></i>Intel Xeon Gold 6138</li>
                    <li><i class="fas fa-check text-green-400 mr-2"></i>4GB RAM</li>
                    <li><i class="fas fa-check text-green-400 mr-2"></i>2 vCPU</li>
                    <li><i class="fas fa-check text-green-400 mr-2"></i>IP dedicada</li>
                    <li><i class="fas fa-check text-green-400 mr-2"></i>Uplink +1Gbps</li>
                    <li><i class="fas fa-check text-green-400 mr-2"></i>20GB SSD</li>
                </ul>
                <button class="w-full bg-blue-600 hover:bg-blue-700 text-white py-2 rounded-lg transition">Contratar Ahora</button>
            </div>
            <div class="card p-5 text-center">
                <h4 class="text-lg font-bold text-yellow-500">Oro</h4>
                <p class="text-2xl font-bold my-2">R$ 94,99 <span class="text-sm font-normal text-gray-400">/mes</span></p>
                <ul class="text-sm text-left space-y-2 my-4 text-gray-300">
                    <li><i class="fas fa-check text-green-400 mr-2"></i>Intel Xeon Gold 6138</li>
                    <li><i class="fas fa-check text-green-400 mr-2"></i>4GB RAM</li>
                    <li><i class="fas fa-check text-green-400 mr-2"></i>4 vCPU</li>
                    <li><i class="fas fa-check text-green-400 mr-2"></i>IP dedicada</li>
                    <li><i class="fas fa-check text-green-400 mr-2"></i>Uplink +1Gbps</li>
                    <li><i class="fas fa-check text-green-400 mr-2"></i>30GB SSD</li>
                </ul>
                <button class="w-full bg-blue-600 hover:bg-blue-700 text-white py-2 rounded-lg transition">Contratar Ahora</button>
            </div>
            <div class="card p-5 text-center">
                <h4 class="text-lg font-bold text-purple-400">Platino</h4>
                <p class="text-2xl font-bold my-2">R$ 114,99 <span class="text-sm font-normal text-gray-400">/mes</span></p>
                <ul class="text-sm text-left space-y-2 my-4 text-gray-300">
                    <li><i class="fas fa-check text-green-400 mr-2"></i>Intel Xeon Gold 6138</li>
                    <li><i class="fas fa-check text-green-400 mr-2"></i>6GB RAM</li>
                    <li><i class="fas fa-check text-green-400 mr-2"></i>4 vCPU</li>
                    <li><i class="fas fa-check text-green-400 mr-2"></i>IP dedicada</li>
                    <li><i class="fas fa-check text-green-400 mr-2"></i>Uplink +1Gbps</li>
                    <li><i class="fas fa-check text-green-400 mr-2"></i>40GB SSD</li>
                </ul>
                <button class="w-full bg-blue-600 hover:bg-blue-700 text-white py-2 rounded-lg transition">Contratar Ahora</button>
            </div>
        </div>

        <!-- Fila inferior: Tickets y Configuración -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <!-- Tickets -->
            <div class="card p-5">
                <h3 class="font-semibold mb-4 flex items-center gap-2">
                    <i class="fas fa-life-ring text-blue-400"></i>
                    Soporte / Tickets
                </h3>
                <div id="tickets-container" class="text-center py-8 text-gray-500">
                    <i class="fas fa-ticket-alt text-4xl mb-2"></i>
                    <p>No se encontraron tickets</p>
                    <button class="mt-4 bg-blue-600 hover:bg-blue-700 px-4 py-2 rounded-lg text-sm transition">
                        <i class="fas fa-plus mr-2"></i>Crear Ticket
                    </button>
                </div>
            </div>

            <!-- Configuración de Tema -->
            <div class="card p-5">
                <h3 class="font-semibold mb-4 flex items-center gap-2">
                    <i class="fas fa-paint-brush text-purple-400"></i>
                    Configuración · Tema
                </h3>
                <p class="text-sm text-gray-400 mb-3">Personaliza tu experiencia</p>
                <div class="flex flex-wrap gap-2 mb-4">
                    <button class="theme-option px-3 py-1 rounded-full text-sm bg-gray-700 text-white" data-theme="dark">Dark</button>
                    <button class="theme-option px-3 py-1 rounded-full text-sm bg-black text-white" data-theme="allblack">All Black</button>
                    <button class="theme-option px-3 py-1 rounded-full text-sm bg-white text-black" data-theme="light">Light</button>
                    <button class="theme-option px-3 py-1 rounded-full text-sm bg-blue-900 text-white" data-theme="midnight">Midnight Blue</button>
                    <button class="theme-option px-3 py-1 rounded-full text-sm bg-emerald-700 text-white" data-theme="emerald">Emerald</button>
                    <button class="theme-option px-3 py-1 rounded-full text-sm bg-rose-500 text-white" data-theme="rose">Rose</button>
                    <button class="theme-option px-3 py-1 rounded-full text-sm bg-orange-500 text-white" data-theme="sunset">Sunset</button>
                    <button class="theme-option px-3 py-1 rounded-full text-sm bg-red-600 text-white" data-theme="natal">Natal</button>
                </div>
                <div class="mt-4">
                    <label class="block text-sm text-gray-400 mb-1">Conta Google</label>
                    <div class="flex items-center gap-2">
                        <input type="email" placeholder="tu@email.com" class="flex-1 bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm">
                        <button class="bg-blue-600 hover:bg-blue-700 px-4 py-2 rounded-lg text-sm">Vincular</button>
                    </div>
                </div>
            </div>
        </div>

        <!-- Footer con activación de Windows (broma) -->
        <div class="mt-8 text-center text-xs text-gray-600">
            Activar Windows · Ve a Configuración para activar Windows.
        </div>
    </div>

    <script>
        // Datos simulados (en un entorno real, vendrían de la API)
        const apiBase = '/api';

        async function fetchData(endpoint) {
            try {
                const res = await fetch(`${apiBase}/${endpoint}`);
                if (!res.ok) throw new Error();
                return await res.json();
            } catch (e) {
                console.warn(`Error fetching ${endpoint}:`, e);
                return null;
            }
        }

        // Cargar datos y actualizar interfaz
        async function loadDashboard() {
            const server = await fetchData('server');
            const backends = await fetchData('backends') || [];
            const users = await fetchData('users') || [];

            // Actualizar tarjetas de resumen
            document.getElementById('active-services').innerText = backends.filter(b => b.status === 'active').length;
            document.getElementById('active-domains').innerText = backends.length; // o dominios reales
            document.getElementById('total-affiliates').innerText = users.length;
            document.getElementById('open-tickets').innerText = '0'; // simulado
            document.getElementById('notifications').innerText = '3'; // simulado

            // Actualizar progreso de CloudFront (simulado)
            const cloudfrontProgress = document.getElementById('cloudfront-progress');
            const cloudfrontStatus = document.getElementById('cloudfront-status');
            const activeBackends = backends.filter(b => b.status === 'active').length;
            const totalBackends = backends.length;
            const percent = totalBackends ? (activeBackends / totalBackends) * 100 : 0;
            cloudfrontProgress.style.width = percent + '%';
            cloudfrontStatus.innerText = `${activeBackends}/${totalBackends} dominios`;

            // Online uptime (simulado)
            const onlineProgress = document.getElementById('online-progress');
            const onlinePercent = document.getElementById('online-percent');
            const uptime = server?.uptime ? 98.8 : 99.2; // simulado
            onlineProgress.style.width = uptime + '%';
            onlinePercent.innerText = uptime + '% uptime';

            // Gráfico de distribución (doughnut)
            const ctxDist = document.getElementById('distributionChart').getContext('2d');
            new Chart(ctxDist, {
                type: 'doughnut',
                data: {
                    labels: ['CloudFront', 'VPS', 'Otros'],
                    datasets: [{
                        data: [activeBackends, 2, 1],
                        backgroundColor: ['#3b82f6', '#10b981', '#f59e0b'],
                        borderWidth: 0
                    }]
                },
                options: {
                    cutout: '70%',
                    plugins: {
                        legend: { display: false },
                        tooltip: { enabled: true }
                    }
                }
            });

            // Gráfico de uptime 24h (simulado)
            const ctxUptime = document.getElementById('uptimeChart').getContext('2d');
            const hours = Array.from({length: 24}, (_, i) => `${i}:00`);
            const uptimeData = hours.map(() => Math.floor(Math.random() * 20 + 80)); // simula 80-100%
            new Chart(ctxUptime, {
                type: 'line',
                data: {
                    labels: hours,
                    datasets: [{
                        label: 'Uptime %',
                        data: uptimeData,
                        borderColor: '#3b82f6',
                        backgroundColor: 'rgba(59, 130, 246, 0.1)',
                        tension: 0.4,
                        fill: true
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: { display: false },
                        tooltip: { callbacks: { label: (ctx) => ctx.raw + '%' } }
                    },
                    scales: {
                        y: { min: 0, max: 100, grid: { color: '#334155' } },
                        x: { ticks: { maxRotation: 45, minRotation: 45 } }
                    }
                }
            });

            // Lista de vencimientos (simulado)
            const expiringList = document.getElementById('expiring-list');
            expiringList.innerHTML = `
                <div class="flex justify-between items-center">
                    <div>
                        <p class="font-medium">CloudFront 30 dias</p>
                        <p class="text-xs text-gray-500">Backend: app292448 · IP: 128.254.188.235</p>
                    </div>
                    <span class="status-badge status-active">19d</span>
                </div>
                <div class="flex justify-between items-center">
                    <div>
                        <p class="font-medium">CloudFront 30 dias</p>
                        <p class="text-xs text-gray-500">Backend: app471073 · IP: 128.254.188.236</p>
                    </div>
                    <span class="status-badge status-active">16d</span>
                </div>
            `;
        }

        // Cambiar tema (simulado)
        document.querySelectorAll('.theme-option').forEach(btn => {
            btn.addEventListener('click', function() {
                const theme = this.dataset.theme;
                // Aquí se podría cambiar variables CSS
                alert('Tema cambiado a ' + theme + ' (simulado)');
            });
        });

        loadDashboard();
    </script>
</body>
</html>
EOF

# ============ CRON PARA BACKUPS ============
cat > /etc/cron.daily/backend-backup << 'EOF'
#!/bin/bash
tar -czf "/root/backend-backups/backup_$(date +%Y%m%d).tar.gz" /etc/backend-manager /etc/nginx/sites-available 2>/dev/null
find /root/backend-backups -name "*.tar.gz" -mtime +30 -delete
EOF
chmod +x /etc/cron.daily/backend-backup
# ============================================================
# SCRIPT PRINCIPAL /root/superc4mpeon.sh (PARTE 1: FUNCIONES ORIGINALES)
# ============================================================
cat > /root/superc4mpeon.sh << 'EOF'
#!/bin/bash

# ==================================================
# SCRIPT EXTENDIDO: BACKEND MANAGER by JOHNNY
# VERSIÓN: 6.0 - 30 OPCIONES + API + PANEL
# ==================================================

# COLORES
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

# ARCHIVOS ORIGINALES
BACKEND_CONF="/etc/nginx/sites-available/superc4mpeon"
BACKEND_ENABLED="/etc/nginx/sites-enabled/superc4mpeon"
USER_DATA="/etc/nginx/superc4mpeon_users.txt"
BACKUP_DIR="/root/superc4mpeon_backups"

# NUEVAS RUTAS
BM_BASE="/etc/backend-manager"
BM_DATA="${BM_BASE}/data"
BM_WEB="/var/www/backend-manager"
BM_BACKUP="/root/backend-backups"
USERS_JSON="${BM_DATA}/users.json"
BACKENDS_JSON="${BM_DATA}/backends.json"
DOMAINS_JSON="${BM_DATA}/domains.json"
TRAFFIC_JSON="${BM_DATA}/traffic.json"
LOGS_JSON="${BM_DATA}/logs.json"
SETTINGS_JSON="${BM_DATA}/settings.json"

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
        if [ -f "$file" ] && [ "$(basename "$file")" != "default" ]; then
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
    if [ "$nginx_status" = "active" ]; then nginx_status="${VERDE}✅ ACTIVO${SEMCOR}"; else nginx_status="${ROJO}❌ INACTIVO${SEMCOR}"; fi

    local api_status="${ROJO}OFF${SEMCOR}"
    curl -s --max-time 1 http://127.0.0.1:5000/api/status >/dev/null 2>&1 && api_status="${VERDE}ON${SEMCOR}"

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
    echo -e "🔧 Nginx: $nginx_status     ${CIAN}📦 Dom:${SEMCOR} $domain_count     ${CIAN}🔙 Back:${SEMCOR} $backends_count     ${CIAN}🧩 API:${SEMCOR} $api_status"
    echo -e "📌 Madre: ${VERDE}$first_domain${SEMCOR}     ${CIAN}📋 Lista:${SEMCOR} $domain_list"
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

# ============ FUNCIONES ORIGINALES DEL SCRIPT v5.0 ============
# (Tomadas textualmente del script de Johnny)

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

# ============ FUNCIONES ORIGINALES EXTRA ============
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
EOF
cat >> /root/superc4mpeon.sh << 'EOF'

# ============ NUEVAS FUNCIONES EXTENDIDAS ============

bm_log_event() {
    local action=$1
    local details=$2
    local timestamp=$(date -Iseconds)
    if command -v jq &>/dev/null && [ -f "$LOGS_JSON" ]; then
        local tmp=$(mktemp)
        jq --arg ts "$timestamp" --arg a "$action" --arg d "$details" \
           '. += [{"timestamp": $ts, "action": $a, "details": $d}]' \
           "$LOGS_JSON" > "$tmp" && mv "$tmp" "$LOGS_JSON"
    fi
}

bm_sync_txt_to_json() {
    command -v jq &>/dev/null || return
    local now=$(date +%s)
    local tmp=$(mktemp)
    echo "[]" > "$tmp"
    if [ -f "$USER_DATA" ] && [ -s "$USER_DATA" ]; then
        while IFS=: read -r name ip port exp; do
            [ -z "$name" ] && continue
            local status="active"
            [[ "$exp" =~ ^[0-9]+$ ]] && [ "$now" -gt "$exp" ] && status="expired"
            local obj=$(jq -n --arg n "$name" --arg i "$ip" --arg p "${port:-80}" --arg s "$status" --argjson e "${exp:-0}" \
                '{name: $n, ip: $i, port: ($p | tonumber), target: ($i + ":" + $p), status: $s, expires_at: $e}')
            jq ". += [$obj]" "$tmp" > "${tmp}.1" && mv "${tmp}.1" "$tmp"
        done < "$USER_DATA"
    fi
    mv "$tmp" "$BACKENDS_JSON" 2>/dev/null
    rm -f "$tmp" 2>/dev/null
}

bm_sync_domains() {
    command -v jq &>/dev/null || return
    local tmp=$(mktemp)
    echo "[]" > "$tmp"
    for file in /etc/nginx/sites-enabled/*; do
        [ -f "$file" ] || continue
        [ "$(basename "$file")" = "default" ] && continue
        domain=$(grep -h server_name "$file" | head -1 | awk '{print $2}' | tr -d ';')
        if [ -n "$domain" ] && [ "$domain" != "_" ]; then
            obj=$(jq -n --arg d "$domain" --arg f "$(basename "$file")" '{domain: $d, file: $f, status: "active"}')
            jq ". += [$obj]" "$tmp" > "${tmp}.1" && mv "${tmp}.1" "$tmp"
        fi
    done
    mv "$tmp" "$DOMAINS_JSON" 2>/dev/null
}

bm_server_monitoring() {
    show_status_panel
    msg -tit "📊 MONITOREO SERVIDOR (EXTENDIDO)"
    echo -e "${CIAN}SISTEMA:${SEMCOR}"
    echo "  Hostname: $(hostname)"
    echo "  Kernel:   $(uname -r)"
    echo "  Uptime:   $(uptime -p)"
    echo "  Load:     $(cat /proc/loadavg | cut -d' ' -f1-3)"
    msg -bar2
    echo -e "${CIAN}CPU:${SEMCOR}"
    echo "  Cores:    $(nproc)"
    echo "  Modelo:   $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
    echo "  Uso:      $(top -bn1 | grep 'Cpu(s)' | awk '{print $2}')%"
    msg -bar2
    echo -e "${CIAN}MEMORIA:${SEMCOR}"
    free -h
    msg -bar2
    echo -e "${CIAN}DISCO:${SEMCOR}"
    df -h /
    read -p "Presiona ENTER..."
}

bm_backend_monitoring() {
    show_status_panel
    msg -tit "📡 MONITOREO BACKENDS (JSON)"
    bm_sync_txt_to_json >/dev/null 2>&1
    if command -v jq &>/dev/null && [ -f "$BACKENDS_JSON" ]; then
        total=$(jq length "$BACKENDS_JSON")
        activos=$(jq '[.[] | select(.status=="active")] | length' "$BACKENDS_JSON")
        expirados=$(jq '[.[] | select(.status=="expired")] | length' "$BACKENDS_JSON")
        echo -e "${CIAN}Resumen:${SEMCOR}"
        echo "  Total: $total | Activos: $activos | Expirados: $expirados"
        echo -e "${CIAN}Detalle:${SEMCOR}"
        jq -r '.[] | "  \(.name) → \(.target) [\(.status)]"' "$BACKENDS_JSON"
    else
        msg -ama "No hay datos JSON (usa jq)"
    fi
    read -p "Presiona ENTER..."
}

bm_traffic_viewer() {
    show_status_panel
    msg -tit "📈 TRÁFICO POR BACKEND"
    if [ -f /var/log/nginx/access.log ]; then
        echo -e "${CIAN}TOP 10 IPs:${SEMCOR}"
        tail -500 /var/log/nginx/access.log | awk '{print $1}' | sort | uniq -c | sort -nr | head -10
        echo -e "${CIAN}Últimas 20 peticiones:${SEMCOR}"
        tail -20 /var/log/nginx/access.log
    else
        msg -ama "No hay log de acceso"
    fi
    read -p "Presiona ENTER..."
}

bm_logs_viewer() {
    show_status_panel
    msg -tit "📋 LOGS DEL SISTEMA (JSON)"
    if command -v jq &>/dev/null && [ -f "$LOGS_JSON" ]; then
        jq -r '.[-20:][] | "\(.timestamp) \(.action): \(.details)"' "$LOGS_JSON"
    else
        msg -ama "No hay logs JSON"
    fi
    read -p "Presiona ENTER..."
}

bm_extended_backup() {
    show_status_panel
    msg -tit "💾 BACKUP EXTENDIDO (JSON + NGINX)"
    local fecha=$(date +%Y%m%d_%H%M%S)
    local archivo="${BM_BACKUP}/full_backup_${fecha}.tar.gz"
    mkdir -p "$BM_BACKUP"
    tar -czf "$archivo" "$BM_BASE" /etc/nginx/sites-available 2>/dev/null
    if [ -f "$archivo" ]; then
        msg -verd "Backup creado: $(basename "$archivo")"
        bm_log_event "BACKUP" "Backup completo: $(basename "$archivo")"
    else
        msg -verm "Error al crear backup"
    fi
    read -p "Presiona ENTER..."
}

bm_api_dashboard_status() {
    show_status_panel
    msg -tit "🧩 ESTADO API / PANEL WEB"
    echo -e "${CIAN}API Flask:${SEMCOR}"
    systemctl status backend-manager-api --no-pager | head -5
    curl -s http://127.0.0.1:5000/api/status | jq . 2>/dev/null || echo "API no responde"
    echo -e "${CIAN}Panel web:${SEMCOR}"
    echo "  URL: http://$(curl -s ifconfig.me):8081"
    echo "  Archivo: $(ls -la $BM_WEB/index.html | awk '{print $9 " (" $5 ")"}')"
    read -p "Presiona ENTER..."
}

# ============ MENÚ PRINCIPAL (CON COLORES ORIGINALES Y OPCIÓN 0 PARA SALIR) ============
main_menu() {
    while true; do
        show_status_panel

        echo -e "${CIAN}════════════════════════════════════════════════════════${SEMCOR}"
        echo -e "${BLANCO}${NEGRITO}                    MENÚ PRINCIPAL                    ${SEMCOR}"
        echo -e "${CIAN}════════════════════════════════════════════════════════${SEMCOR}"
        echo -e " ${VERDE}[01]${SEMCOR} ${BLANCO}INSTALAR NGINX (80)${SEMCOR}"
        echo -e " ${VERDE}[02]${SEMCOR} ${BLANCO}INSTALAR PROXY PYTHON (8080)${SEMCOR}"
        echo -e " ${VERDE}[03]${SEMCOR} ${BLANCO}GESTIONAR BACKENDS PERSONALIZADOS${SEMCOR}"
        echo -e " ${VERDE}[04]${SEMCOR} ${BLANCO}VER ESTADO DEL SISTEMA${SEMCOR}"
        echo -e " ${VERDE}[05]${SEMCOR} ${BLANCO}INSTRUCCIONES Y PAYLOADS${SEMCOR}"
        echo -e " ${VERDE}[06]${SEMCOR} ${BLANCO}EDITAR CONFIGURACIÓN MANUAL${SEMCOR}"
        echo -e " ${VERDE}[07]${SEMCOR} ${BLANCO}REINICIAR SERVICIOS${SEMCOR}"
        echo -e " ${VERDE}[08]${SEMCOR} ${BLANCO}GESTIÓN DE BACKUPS${SEMCOR}"
        echo -e " ${VERDE}[09]${SEMCOR} ${BLANCO}LIMPIAR BACKENDS EXPIRADOS${SEMCOR}"
        echo -e " ${VERDE}[10]${SEMCOR} ${BLANCO}HEALTHCHECK (HTTP Y LATENCIA)${SEMCOR}"
        echo -e " ${VERDE}[11]${SEMCOR} ${BLANCO}VALIDAR CONEXIÓN (HEADER)${SEMCOR}"
        echo -e " ${VERDE}[12]${SEMCOR} ${BLANCO}EDITAR TIMEOUTS${SEMCOR}"
        echo -e " ${VERDE}[13]${SEMCOR} ${BLANCO}BALANCEO DE MADRES${SEMCOR}"
        echo -e " ${VERDE}[14]${SEMCOR} ${BLANCO}LIMITAR ANCHO DE BANDA${SEMCOR}"
        echo -e " ${VERDE}[15]${SEMCOR} ${BLANCO}TRÁFICO POR IP (STATS)${SEMCOR}"
        echo -e " ${VERDE}[16]${SEMCOR} ${BLANCO}FIREWALL UFW${SEMCOR}"
        echo -e " ${VERDE}[17]${SEMCOR} ${BLANCO}SPEEDTEST${SEMCOR}"
        echo -e " ${VERDE}[18]${SEMCOR} ${BLANCO}MANTENIMIENTO PROGRAMADO${SEMCOR}"
        echo -e " ${VERDE}[19]${SEMCOR} ${BLANCO}DESINSTALAR TODO${SEMCOR}"
        echo -e "${TURQUESA}═════════════════ OPCIONES EXTENDIDAS ═════════════════${SEMCOR}"
        echo -e " ${CIAN}[21]${SEMCOR} ${BLANCO}📊 MONITOREO SERVIDOR (DETALLADO)${SEMCOR}"
        echo -e " ${CIAN}[22]${SEMCOR} ${BLANCO}📡 MONITOREO BACKENDS (JSON)${SEMCOR}"
        echo -e " ${CIAN}[23]${SEMCOR} ${BLANCO}📈 VER TRÁFICO POR BACKEND${SEMCOR}"
        echo -e " ${CIAN}[24]${SEMCOR} ${BLANCO}📋 VER LOGS DEL SISTEMA${SEMCOR}"
        echo -e " ${CIAN}[25]${SEMCOR} ${BLANCO}💾 BACKUP EXTENDIDO (JSON+NGINX)${SEMCOR}"
        echo -e " ${CIAN}[26]${SEMCOR} ${BLANCO}🧩 ESTADO API / PANEL WEB${SEMCOR}"
        echo -e " ${CIAN}[27]${SEMCOR} ${BLANCO}🌐 ABRIR PANEL WEB EN NAVEGADOR${SEMCOR}"
        echo -e " ${CIAN}[28]${SEMCOR} ${BLANCO}🔄 SINCRONIZAR TXT A JSON${SEMCOR}"
        echo -e " ${CIAN}[29]${SEMCOR} ${BLANCO}📦 VER ESTADÍSTICAS JSON${SEMCOR}"
        echo -e " ${CIAN}[30]${SEMCOR} ${BLANCO}⚙️  CONFIGURAR AJUSTES (settings.json)${SEMCOR}"
        echo -e "${CIAN}════════════════════════════════════════════════════════${SEMCOR}"
        echo -e " ${ROJO}[0]${SEMCOR} ${BLANCO}SALIR DEL SCRIPT${SEMCOR}"
        echo -e "${CIAN}════════════════════════════════════════════════════════${SEMCOR}"

        read -p "🔥 SELECCIONA OPCIÓN: " option

        case $option in
            # OPCIONES ORIGINALES 1-19
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
            # NUEVAS OPCIONES 21-30
            21) bm_server_monitoring ;;
            22) bm_backend_monitoring ;;
            23) bm_traffic_viewer ;;
            24) bm_logs_viewer ;;
            25) bm_extended_backup ;;
            26) bm_api_dashboard_status ;;
            27) 
                ip=$(curl -s ifconfig.me)
                echo -e "${CIAN}Abre en tu navegador: http://${ip}:8081${SEMCOR}"
                read -p "Presiona ENTER..."
                ;;
            28) 
                bm_sync_txt_to_json
                msg -verd "Sincronización completada"
                read -p "Presiona ENTER..."
                ;;
            29)
                if command -v jq &>/dev/null; then
                    jq '.' "$BACKENDS_JSON" 2>/dev/null | less
                else
                    msg -verm "jq no instalado"
                fi
                ;;
            30)
                nano "$SETTINGS_JSON"
                msg -verd "Ajustes guardados (si se editó)"
                ;;
            0)
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
echo -e "\E[41;1;37m         CARGANDO BACKEND MANAGER EXTENDIDO....         \E[0m"
echo -e "${TURQUESA}════════════════════════════════════════════════════════${SEMCOR}"
echo -e "${SEMCOR}"
echo -e "${VERDE}${NEGRITO}              CARGANDO SISTEMA...${SEMCOR}"
sleep 2

init_system
main_menu
EOF
# ============ HACER EJECUTABLE Y CREAR ENLACE ============
chmod +x /root/superc4mpeon.sh
ln -sf /root/superc4mpeon.sh /bin/menu2

# ============ VERIFICAR SERVICIOS ============
systemctl restart nginx
systemctl enable backend-manager-api
systemctl restart backend-manager-api

# ============ MENSAJE FINAL ============
echo -e "${VERDE}════════════════════════════════════════════════════════${SEMCOR}"
echo -e "\E[42;1;37m  ✅ INSTALACIÓN EXTENDIDA COMPLETADA CON ÉXITO  \E[0m"
echo -e "${VERDE}════════════════════════════════════════════════════════${SEMCOR}"
IP=$(curl -s ifconfig.me)
echo -e "${CIAN}📌 ACCESOS:${SEMCOR}"
echo -e "   ${VERDE}•${SEMCOR} Menú CLI: ${TURQUESA}menu2${SEMCOR}"
echo -e "   ${VERDE}•${SEMCOR} Panel web: ${TURQUESA}http://${IP}:8081${SEMCOR}"
echo -e "   ${VERDE}•${SEMCOR} API: ${TURQUESA}http://${IP}:8081/api/status${SEMCOR}"
echo -e "${AMARILLO}⚠️  Los puertos 80 y 8080 quedan libres para tu configuración manual.${SEMCOR}"
echo -e "${AMARILLO}⚠️  Para SSL con Cloudflare, solo apunta tu dominio a esta IP y configura el certificado en el panel.${SEMCOR}"
echo -e "${VERDE}════════════════════════════════════════════════════════${SEMCOR}"
