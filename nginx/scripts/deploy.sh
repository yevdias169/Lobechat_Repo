#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   DOMAIN=chat.dev.jimboslice.xyz bash scripts/deploy.sh
# If DOMAIN is unset, defaults to anomaly.jimboslice.xyz
DOMAIN="${DOMAIN:-chat.dev.jimboslice.xyz}"

echo ">> Using domain: $DOMAIN"

# 1) Ensure Docker + Compose
if ! command -v docker >/dev/null 2>&1; then
  echo ">> Installing Docker..."
  curl -fsSL https://get.docker.com | sh
  sudo systemctl enable docker
  sudo systemctl start docker
fi

if ! docker compose version >/dev/null 2>&1; then
  echo ">> Installing docker-compose-plugin (compose v2)..."
  # Debian/Ubuntu typical:
  sudo apt-get update
  sudo apt-get install -y docker-compose-plugin
fi

# 2) Ensure .env exists and contains OPENAI_API_KEY
if [ ! -f ".env" ]; then
  echo "ERROR: .env not found. Copy .env.example to .env and set OPENAI_API_KEY." >&2
  exit 1
fi
if ! grep -q "^OPENAI_API_KEY=" .env; then
  echo "ERROR: OPENAI_API_KEY is missing in .env." >&2
  exit 1
fi

# 3) Start/Update the container
echo ">> Launching LobeChat via Docker Compose..."
docker compose pull
docker compose up -d

# 4) Install Nginx + Certbot
echo ">> Installing Nginx + Certbot (if needed)..."
sudo apt-get update
sudo apt-get install -y nginx certbot python3-certbot-nginx

# 5) Install Nginx site for the subdomain
SITE_AVAIL="/etc/nginx/sites-available/lobe-chat.conf"
SITE_ENABL="/etc/nginx/sites-enabled/lobe-chat.conf"

echo ">> Writing Nginx config for $DOMAIN ..."
sudo mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled
sudo bash -c "sed 's/chat.dev.jimboslice.xyz/$DOMAIN/g' nginx/lobe-chat.conf.template > '$SITE_AVAIL'"
sudo ln -sf "$SITE_AVAIL" "$SITE_ENABL"
sudo nginx -t
sudo systemctl reload nginx

# 6) HTTPS certificate
echo ">> Requesting HTTPS certificate for $DOMAIN ..."
sudo certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m admin@${DOMAIN#*.}

echo ">> Deployed. Open: https://$DOMAIN"
