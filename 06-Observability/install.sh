#!/usr/bin/env bash
set -e

STACK_NAME="traefik"
DOMAIN="4b51b3d0a51c.mylabserver.com"

echo "Creando estructura de directorios..."
mkdir -p prometheus
mkdir -p grafana/provisioning/datasources
mkdir -p grafana/provisioning/dashboards

########################################
# docker-compose.yml
########################################
cat > docker-compose.yml <<'EOF'
version: '3.7'

services:
  traefik:
    image: traefik:v2.3
    networks:
      - traefik
      - inbound
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./traefik.metrics.yml:/etc/traefik/traefik.yml
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.traefik.rule=Host(`traefik.localhost`)"
        - "traefik.http.routers.traefik.entrypoints=web"
        - "traefik.http.routers.traefik.service=api@internal"
        - "traefik.docker.network=inbound"

  prometheus:
    image: prom/prometheus:v2.22.1
    networks:
      - inbound
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/:/etc/prometheus/
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.prometheus.rule=Host(`prometheus.localhost`)"
        - "traefik.http.routers.prometheus.entrypoints=web"
        - "traefik.http.services.prometheus.loadbalancer.server.port=9090"
        - "traefik.docker.network=inbound"

  grafana:
    image: grafana/grafana:7.3.1
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
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.grafana.rule=Host(`grafana.localhost`)"
        - "traefik.http.routers.grafana.entrypoints=web"
        - "traefik.http.services.grafana.loadbalancer.server.port=3000"
        - "traefik.docker.network=inbound"

  catapp:
    image: mikesir87/cats:1.0
    networks:
      - inbound
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.catapp.rule=Host(`4b51b3d0a51c.mylabserver.com`)"
        - "traefik.http.routers.catapp.entrypoints=web"
        - "traefik.http.routers.catapp.middlewares=test-compress,test-errorpages"
        - "traefik.http.services.catapp.loadbalancer.server.port=5000"
        - "traefik.http.middlewares.test-compress.compress=true"
        - "traefik.http.middlewares.test-errorpages.errors.status=400-599"
        - "traefik.http.middlewares.test-errorpages.errors.service=error"
        - "traefik.http.middlewares.test-errorpages.errors.query=/{status}.html"
        - "traefik.docker.network=inbound"

  error:
    image: guillaumebriday/traefik-custom-error-pages
    networks:
      - inbound
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.error.rule=Host(`error.localhost`)"
        - "traefik.http.routers.error.entrypoints=web"
        - "traefik.http.services.error.loadbalancer.server.port=80"
        - "traefik.docker.network=inbound"

networks:
  traefik:
    driver: overlay
    name: traefik
  inbound:
    driver: overlay
    name: inbound

volumes:
  prometheus_data: {}
  grafana_data: {}
EOF

########################################
# prometheus/prometheus.yml
########################################
cat > prometheus/prometheus.yml <<'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'traefik'
    static_configs:
      - targets: ['traefik:8082']
EOF

########################################
# grafana/config.monitoring
########################################
cat > grafana/config.monitoring <<'EOF'
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=admin
GF_USERS_ALLOW_SIGN_UP=false
EOF

########################################
# traefik.metrics.yml (config básica con métricas)
########################################
cat > traefik.metrics.yml <<'EOF'
entryPoints:
  web:
    address: ":80"
  traefik:
    address: ":8080"

api:
  dashboard: true

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false

metrics:
  prometheus:
    entryPoint: "traefik"
EOF

echo "Inicializando swarm (si no existe)..."
docker swarm init 2>/dev/null || true

echo "Desplegando stack ${STACK_NAME}..."
docker stack deploy -c docker-compose.yml "${STACK_NAME}"

echo
echo "Listo."
echo " - App de gatos:     http://4b51b3d0a51c.mylabserver.com"
echo " - Traefik dashboard: http://<host>:8080"
echo " - Prometheus:       http://<host>:9090"
echo " - Grafana:          http://<host>:3000 (admin/admin)"
EOF
