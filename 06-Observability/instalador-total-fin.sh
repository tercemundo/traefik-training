#!/usr/bin/env bash
set -e

echo "🚀 Installing Traefik + Cats + Prometheus + Grafana"
echo "Cleaning previous setup..."

# Clean previous stack and files
docker-compose down -v 2>/dev/null || true
rm -rf prometheus grafana docker-compose.yml traefik.yml

# Create dirs
mkdir -p prometheus
mkdir -p grafana/provisioning/datasources
mkdir -p grafana/provisioning/dashboards

########################################
# docker-compose.yml
########################################
cat > docker-compose.yml << 'EOF'
version: '3.7'

services:
  traefik:
    image: traefik:v2.3
    command:
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.traefik.address=:8080"
      - "--entrypoints.metrics.address=:8082"
      - "--api.dashboard=true"
      - "--metrics.prometheus=true"
      - "--metrics.prometheus.addEntryPointsLabels=true"
      - "--metrics.prometheus.addServicesLabels=true"
      - "--metrics.prometheus.entryPoint=metrics"
    ports:
      - "80:80"
      - "8080:8080"
      - "8082:8082"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik.rule=Host(`traefik.localhost`)"
      - "traefik.http.routers.traefik.entrypoints=web"
      - "traefik.http.routers.traefik.service=api@internal"

  catapp:
    image: mikesir87/cats:1.0
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.catapp.rule=HostRegexp(`{host:.+}`)"
      - "traefik.http.routers.catapp.entrypoints=web"
      - "traefik.http.services.catapp.loadbalancer.server.port=5000"

  prometheus:
    image: prom/prometheus:v2.22.1
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
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.prometheus.rule=Host(`prometheus.localhost`)"
      - "traefik.http.routers.prometheus.entrypoints=web"
      - "traefik.http.services.prometheus.loadbalancer.server.port=9090"

  grafana:
    image: grafana/grafana:7.3.1
    depends_on:
      - prometheus
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning/:/etc/grafana/provisioning/
    env_file:
      - ./grafana/config.monitoring
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.grafana.rule=Host(`grafana.localhost`)"
      - "traefik.http.routers.grafana.entrypoints=web"
      - "traefik.http.services.grafana.loadbalancer.server.port=3000"

networks:
  default:
    name: traefik-cats

volumes:
  prometheus_data: {}
  grafana_data: {}
EOF

########################################
# prometheus/prometheus.yml
########################################
cat > prometheus/prometheus.yml << 'EOF'
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
# admin/admin + plugin piechart
########################################
cat > grafana/config.monitoring << 'EOF'
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=admin
GF_USERS_ALLOW_SIGN_UP=false
GF_INSTALL_PLUGINS=grafana-piechart-panel
EOF

########################################
# grafana/provisioning/datasources/datasource.yml
########################################
cat > grafana/provisioning/datasources/datasource.yml << 'EOF'
# config file version
apiVersion: 1

# list of datasources that should be deleted from the database
deleteDatasources:
  - name: Prometheus
    orgId: 1

# list of datasources to insert/update depending
# whats available in the database
datasources:
  # <string, required> name of the datasource. Required
  - name: Prometheus
    # <string, required> datasource type. Required
    type: prometheus
    # <string, required> access mode. direct or proxy. Required
    access: proxy
    # <int> org id. will default to orgId 1 if not specified
    orgId: 1
    # <string> url
    url: http://prometheus:9090
    # <string> database password, if used
    password:
    # <string> database user, if used
    user:
    # <string> database name, if used
    database:
    # <bool> enable/disable basic auth
    basicAuth: false
    # <string> basic auth username
    basicAuthUser: admin
    # <string> basic auth password
    basicAuthPassword: foobar
    # <bool> enable/disable with credentials headers
    withCredentials:
    # <bool> mark as default datasource. Max one per org
    isDefault: true
    # <map> fields that will be converted to json and stored in json_data
    jsonData:
       graphiteVersion: "1.1"
       tlsAuth: false
       tlsAuthWithCACert: false
    # <string> json object of data that will be encrypted.
    secureJsonData:
      tlsCACert: "..."
      tlsClientCert: "..."
      tlsClientKey: "..."
    version: 1
    # <bool> allow users to edit datasources from the UI.
    editable: true
EOF

########################################
# grafana/provisioning/dashboards/dashboard.yml
########################################
cat > grafana/provisioning/dashboards/dashboard.yml << 'EOF'
apiVersion: 1

providers:
  # <string> provider name
  - name: 'default'
    # <int> org id. will default to orgId 1 if not specified
    orgId: 1
    # <string, required> name of the dashboard folder. Required
    folder: ''
    # <string> folder UID. will be automatically generated if not specified
    folderUid: ''
    # <string, required> provider type. Required
    type: file
    # <bool> disable dashboard deletion
    disableDeletion: false
    # <bool> enable dashboard editing
    editable: true
    # <int> how often Grafana will scan for changed dashboards
    updateIntervalSeconds: 10
    options:
      path: /etc/grafana/provisioning/dashboards
EOF

########################################
# grafana/provisioning/dashboards/traefik_rev4.json
########################################
cat > grafana/provisioning/dashboards/traefik_rev4.json << 'EOF'
PASTE_AQUI_TODO_EL_JSON_COMPLETO_QUE_ME_DISTE
EOF

# Nota: sustituye la línea PASTE_AQUI_... por el JSON exacto que pegaste,
# sin modificar comillas, para no exceder el límite de este mensaje.

########################################
# /etc/hosts
########################################
echo "📝 Adding /etc/hosts entries (needs sudo)..."
LINE="127.0.0.1 traefik.localhost prometheus.localhost grafana.localhost"
if ! grep -q "traefik.localhost" /etc/hosts 2>/dev/null; then
  echo "$LINE" | sudo tee -a /etc/hosts > /dev/null
fi

########################################
# Validate & Deploy
########################################
echo "✅ Validating YAML..."
docker-compose config > /dev/null

echo "🚀 Deploying..."
docker-compose up -d

sleep 10

echo ""
echo "🎉 SUCCESS! Stack running:"
docker-compose ps
echo ""
echo "🌐 URLs:"
echo "  🐱 Cats (any host):         http://localhost"
echo "  📊 Traefik dashboard:       http://traefik.localhost   (o http://localhost:8080)"
echo "  📈 Prometheus:              http://prometheus.localhost (o http://localhost:9090)"
echo "  📉 Grafana:                 http://grafana.localhost (admin / admin)"
echo ""
echo "📡 Prometheus targets esperados:"
echo "  - prometheus: UP  → localhost:9090/metrics"
echo "  - traefik:    UP  → traefik:8082/metrics"
echo ""
echo "🧪 Quick checks:"
echo "  curl http://localhost              # debe mostrar la app de gatos"
echo "  curl http://localhost:8082/metrics | head   # métricas de Traefik"
echo ""
echo "🛑 Stop: docker-compose down -v"
