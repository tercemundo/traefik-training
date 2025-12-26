#!/usr/bin/env bash
set -e

BASE_DIR="$(pwd)"

echo "==> Creando estructura de directorios..."
mkdir -p "${BASE_DIR}/prometheus"
mkdir -p "${BASE_DIR}/grafana/provisioning/datasources"
mkdir -p "${BASE_DIR}/grafana/provisioning/dashboards"

########################################
# /etc/hosts
########################################
HOSTS_ENTRIES=(
  "127.0.0.1 catapp.localhost"
  "127.0.0.1 prometheus.localhost"
  "127.0.0.1 grafana.localhost"
  "127.0.0.1 traefik.localhost"
)

echo "==> Añadiendo hosts a /etc/hosts (requiere sudo)..."
for entry in "${HOSTS_ENTRIES[@]}"; do
  if ! grep -q "$entry" /etc/hosts; then
    echo "  + $entry"
    echo "$entry" | sudo tee -a /etc/hosts >/dev/null
  else
    echo "  = $entry (ya existe)"
  fi
done

########################################
# docker-compose.yml
########################################
echo "==> Generando docker-compose.yml..."
cat > "${BASE_DIR}/docker-compose.yml" << 'EOF'
version: '3.7'

services:
  traefik:
    image: traefik:v2.10
    container_name: traefik
    networks:
      - traefik
      - inbound
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
      - "8082:8082"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    command:
      - --api.insecure=true
      - --providers.docker=true
      - --providers.docker.exposedByDefault=false
      - --entrypoints.web.address=:80
      - --entrypoints.metrics.address=:8082
      - --metrics.prometheus=true
      - --metrics.prometheus.entrypoint=metrics
      - --metrics.prometheus.addentrypointslabels=true
      - --metrics.prometheus.addrouterslabels=true
      - --metrics.prometheus.addserviceslabels=true
    labels:
      - traefik.enable=true
      - traefik.http.routers.traefik.rule=Host(`traefik.localhost`)
      - traefik.http.routers.traefik.entrypoints=web
      - traefik.http.services.traefik.loadbalancer.server.port=8080

  prometheus:
    image: prom/prometheus:v2.22.1
    container_name: prometheus
    networks:
      - inbound
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
    labels:
      - traefik.enable=true
      - traefik.http.routers.prometheus.rule=Host(`prometheus.localhost`)
      - traefik.http.routers.prometheus.entrypoints=web
      - traefik.http.services.prometheus.loadbalancer.server.port=9090

  grafana:
    image: grafana/grafana:7.3.1
    container_name: grafana
    networks:
      - inbound
    depends_on:
      - prometheus
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning/:/etc/grafana/provisioning/
    env_file:
      - ./grafana/config.monitoring
    user: "104"
    labels:
      - traefik.enable=true
      - traefik.http.routers.grafana.rule=Host(`grafana.localhost`)
      - traefik.http.routers.grafana.entrypoints=web
      - traefik.http.services.grafana.loadbalancer.server.port=3000

  catapp:
    image: mikesir87/cats:1.0
    container_name: catapp
    networks:
      - inbound
    ports:
      - "5000:5000"
    labels:
      - traefik.enable=true
      - traefik.http.routers.catapp.rule=Host(`catapp.localhost`)
      - traefik.http.routers.catapp.entrypoints=web
      - traefik.http.routers.catapp.middlewares=test-compress,test-errorpages
      - traefik.http.services.catapp.loadbalancer.server.port=5000
      - traefik.http.middlewares.test-compress.compress=true
      - traefik.http.middlewares.test-errorpages.errors.status=400-599
      - traefik.http.middlewares.test-errorpages.errors.service=error
      - traefik.http.middlewares.test-errorpages.errors.query=/{status}.html

  error:
    image: guillaumebriday/traefik-custom-error-pages
    container_name: error-pages
    networks:
      - inbound
    ports:
      - "8081:80"
    labels:
      - traefik.enable=true
      - traefik.http.routers.error.rule=Host(`error.localhost`)
      - traefik.http.routers.error.entrypoints=web
      - traefik.http.services.error.loadbalancer.server.port=80

networks:
  traefik:
    driver: bridge
  inbound:
    driver: bridge

volumes:
  prometheus_data: {}
  grafana_data: {}
EOF

########################################
# prometheus.yml
########################################
echo "==> Generando prometheus/prometheus.yml..."
cat > "${BASE_DIR}/prometheus/prometheus.yml" << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'traefik'
    scrape_interval: 5s
    static_configs:
      - targets: ['traefik:8082']
EOF

########################################
# Grafana: datasource Prometheus
########################################
echo "==> Generando grafana/provisioning/datasources/prometheus.yml..."
cat > "${BASE_DIR}/grafana/provisioning/datasources/prometheus.yml" << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
EOF

########################################
# Grafana: dashboard provider
########################################
echo "==> Generando grafana/provisioning/dashboards/traefik.yml..."
cat > "${BASE_DIR}/grafana/provisioning/dashboards/traefik.yml" << 'EOF'
apiVersion: 1

providers:
  - name: traefik
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    editable: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF

########################################
# Grafana: dashboard JSON (traefik_rev4)
########################################
echo "==> Guardando dashboard de Traefik..."
cat > "${BASE_DIR}/grafana/provisioning/dashboards/traefik_rev4.json" << 'EOF'
PASTE_AQUI_TU_JSON_COMPLETO_DEL_DASHBOARD
EOF

echo "==> Recuerda editar grafana/provisioning/dashboards/traefik_rev4.json y pegar el JSON completo del dashboard."
echo "==> También crea grafana/config.monitoring si no existe (GF_SECURITY_ADMIN_PASSWORD, etc.)."

echo "==> Levantando stack con Docker Compose v2..."
docker compose down || true
docker compose up -d

echo "==> Listo."
echo "  - Traefik:     http://traefik.localhost:80 (dashboard en :8080)"
echo "  - Prometheus:  http://prometheus.localhost:9090/targets"
echo "  - Grafana:     http://grafana.localhost:3000"
echo "  - Catapp:      http://catapp.localhost"
