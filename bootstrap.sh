#!/bin/bash
set -e

BASE="http://localhost:81"
EMAIL="admin@buildwithkulshresth.com"
PASSWORD="KaizexAdmin2026!"

echo "==> Waiting for NPM API..."
until curl -sf "$BASE/api/" > /dev/null 2>&1; do
  echo "   not ready yet, retrying..."
  sleep 3
done
echo "   NPM is up."

# ── Check if first-time setup needed ──────────────────────────────
SETUP=$(curl -sf "$BASE/api/" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('setup', False))")

if [ "$SETUP" = "False" ]; then
  echo "==> First-time setup — creating admin user..."
  curl -sf -X POST "$BASE/api/users/" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"Admin\",
      \"nickname\": \"Admin\",
      \"email\": \"$EMAIL\",
      \"roles\": [\"admin\"],
      \"is_disabled\": false,
      \"auth\": {
        \"type\": \"password\",
        \"secret\": \"$PASSWORD\"
      }
    }" | python3 -c "import sys,json; d=json.load(sys.stdin); print('Created user:', d.get('email','?'))"
else
  echo "==> Admin already exists, skipping user creation."
fi

# ── Login ──────────────────────────────────────────────────────────
echo "==> Logging in..."
TOKEN=$(curl -sf -X POST "$BASE/api/tokens/" \
  -H "Content-Type: application/json" \
  -d "{\"identity\":\"$EMAIL\",\"secret\":\"$PASSWORD\"}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")
echo "   Got token."

# ── Advanced nginx config (all routes) ────────────────────────────
ADVANCED_CONFIG='
location /kaizex/ {
    proxy_pass         http://static-kaizex:80/;
    proxy_http_version 1.1;
    proxy_set_header   Host              $host;
    proxy_set_header   X-Real-IP         $remote_addr;
    proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header   X-Forwarded-Proto $scheme;
}
location = /kaizex { return 301 /kaizex/; }

location /sso/ {
    proxy_pass         http://static-sso:80/;
    proxy_http_version 1.1;
    proxy_set_header   Host              $host;
    proxy_set_header   X-Real-IP         $remote_addr;
    proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header   X-Forwarded-Proto $scheme;
}
location = /sso { return 301 /sso/; }

location /drip/ {
    proxy_pass         http://static-drip:80/;
    proxy_http_version 1.1;
    proxy_set_header   Host              $host;
    proxy_set_header   X-Real-IP         $remote_addr;
    proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header   X-Forwarded-Proto $scheme;
}
location = /drip { return 301 /drip/; }

location /smat-server/ {
    proxy_pass         http://host.docker.internal:8090/;
    proxy_http_version 1.1;
    proxy_set_header   Host              $host;
    proxy_set_header   X-Real-IP         $remote_addr;
    proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header   X-Forwarded-Proto $scheme;
}
location = /smat-server { return 301 /smat-server/; }

location /sso-server/ {
    proxy_pass         http://host.docker.internal:9000/;
    proxy_http_version 1.1;
    proxy_set_header   Host              $host;
    proxy_set_header   X-Real-IP         $remote_addr;
    proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header   X-Forwarded-Proto $scheme;
}
location = /sso-server { return 301 /sso-server/; }

location /session-logger/ {
    proxy_pass         http://host.docker.internal:3001/;
    proxy_http_version 1.1;
    proxy_set_header   Host              $host;
    proxy_set_header   X-Real-IP         $remote_addr;
    proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header   X-Forwarded-Proto $scheme;
}
location = /session-logger { return 301 /session-logger/; }

location /api/ {
    proxy_pass         http://host.docker.internal:3001/api/;
    proxy_http_version 1.1;
    proxy_set_header   Host              $host;
    proxy_set_header   X-Real-IP         $remote_addr;
    proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header   X-Forwarded-Proto $scheme;
}

location /grafana/ {
    proxy_pass         http://host.docker.internal:3000/;
    proxy_http_version 1.1;
    proxy_set_header   Host              $host;
    proxy_set_header   X-Real-IP         $remote_addr;
    proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header   X-Forwarded-Proto $scheme;
    proxy_set_header   Upgrade           $http_upgrade;
    proxy_set_header   Connection        "upgrade";
    proxy_redirect     http://localhost/  /;
    proxy_redirect     http://host.docker.internal:3000/  /grafana/;
}
location = /grafana { return 301 /grafana/; }

location /drip-api/ {
    proxy_pass         http://host.docker.internal:3002/;
    proxy_http_version 1.1;
    proxy_set_header   Host              $host;
    proxy_set_header   X-Real-IP         $remote_addr;
    proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header   X-Forwarded-Proto $scheme;
    proxy_set_header   Upgrade           $http_upgrade;
    proxy_set_header   Connection        "upgrade";
    proxy_read_timeout 86400;
    proxy_send_timeout 86400;
}
location = /drip-api { return 301 /drip-api/; }

location /webhook/ {
    proxy_pass           http://host.docker.internal:3550/;
    proxy_http_version   1.1;
    proxy_set_header     Host              $host;
    proxy_set_header     X-Real-IP         $remote_addr;
    proxy_set_header     X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header     X-Forwarded-Proto $scheme;
    proxy_buffering      off;
    client_max_body_size 10M;
}
location = /webhook { return 301 /webhook/dashboard/; }

location /npm/ {
    proxy_pass         http://127.0.0.1:81/;
    proxy_http_version 1.1;
    proxy_set_header   Host              $host;
    proxy_set_header   X-Real-IP         $remote_addr;
    proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header   X-Forwarded-Proto $scheme;
    proxy_set_header   Upgrade           $http_upgrade;
    proxy_set_header   Connection        "upgrade";
}
location = /npm { return 301 /npm/; }
'

# ── Escape config for JSON ─────────────────────────────────────────
ESCAPED=$(echo "$ADVANCED_CONFIG" | python3 -c "
import sys, json
print(json.dumps(sys.stdin.read()))
" | sed 's/^"//;s/"$//')

# ── Create proxy host ──────────────────────────────────────────────
echo "==> Creating proxy host for buildwithkulshresth.com..."
RESULT=$(curl -sf -X POST "$BASE/api/nginx/proxy-hosts/" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{
    \"domain_names\": [\"buildwithkulshresth.com\"],
    \"forward_scheme\": \"http\",
    \"forward_host\": \"static-portfolio\",
    \"forward_port\": 80,
    \"block_exploits\": true,
    \"allow_websocket_upgrade\": true,
    \"http2_support\": false,
    \"hsts_enabled\": false,
    \"hsts_subdomains\": false,
    \"ssl_forced\": false,
    \"caching_enabled\": false,
    \"access_list_id\": \"0\",
    \"certificate_id\": 0,
    \"locations\": [],
    \"advanced_config\": \"$ESCAPED\"
  }")

echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print('Created proxy host ID:', d.get('id','?'), 'for', d.get('domain_names','?'))"

echo ""
echo "==> Done. All routes are live."
echo "    NPM admin: buildwithkulshresth.com/npm/"
echo "    Credentials: $EMAIL / $PASSWORD"
echo "    Change your password after first login!"
