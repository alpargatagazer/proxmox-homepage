#!/usr/bin/env bash
# Homepage Manager Script
# Simplifies deployment, local testing, and Git Sync automation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

GIT_SYNC_SERVICE="homepage-git-sync"
TARGET_DIR="/opt/homepage/config"

# Check for gettext-base (envsubst) which is required for templates on Debian
if ! command -v envsubst &> /dev/null; then
    echo "⚠️ 'envsubst' not found. This is required for templates."
    echo "🔧 Installing gettext-base (requires sudo)..."
    apt-get update && apt-get install -y gettext-base
fi

# Load environment variables
if [ -f .env ]; then
    set -a
    source .env
    set +a
else
    echo "⚠️ .env file not found! Copy .env.example to .env and fill in the values."
    exit 1
fi

generate_configs() {
    echo "📄 Generating .yaml config files from templates..."
    for template in "$SCRIPT_DIR"/config/*.yaml.template; do
        if [ -f "$template" ]; then
            filename=$(basename "$template" .template)
            envsubst < "$template" > "$SCRIPT_DIR/config/$filename"
            echo "   ✅ Generated $filename"
        fi
    done
}

deploy_configs() {
    echo "📦 Deploying configs to $TARGET_DIR..."
    mkdir -p "$TARGET_DIR"
    cp "$SCRIPT_DIR"/config/*.yaml "$TARGET_DIR/"
    echo "✅ Configs deployed to $TARGET_DIR"
}

usage() {
    echo "Usage: $0 {deploy|test-local|test-down|self-update|setup-git-sync}"
    echo ""
    echo "Commands:"
    echo "  deploy            : Generate configs and copy them to $TARGET_DIR (LXC usage)"
    echo "  test-local        : Generate configs and start local Docker testing environment"
    echo "  test-down         : Stop the local Docker testing environment"
    echo ""
    echo "Git Sync (Code Updates):"
    echo "  self-update       : Check for changes in 'main' and redeploy if found"
    echo "  setup-git-sync    : Create systemd timer for auto-code-updates"
}

case "$1" in
    deploy)
        generate_configs
        deploy_configs
        ;;
    test-local)
        generate_configs
        echo "🚀 Starting Local Proxmox Homepage..."
        docker compose pull
        docker compose up -d --remove-orphans
        echo "✅ Local testing environment is up."
        ;;
    test-down)
        echo "🛑 Stopping Local Proxmox Homepage..."
        docker compose down
        echo "✅ Local testing environment stopped."
        ;;
    self-update)
        echo "🔄 Checking for code updates in repository..."
        git fetch origin main || true
        
        UPSTREAM=${1:-'@{u}'}
        LOCAL=$(git rev-parse @ 2>/dev/null || echo "")
        REMOTE=$(git rev-parse "$UPSTREAM" 2>/dev/null || echo "")
        BASE=$(git merge-base @ "$UPSTREAM" 2>/dev/null || echo "")

        if [ -z "$LOCAL" ] || [ -z "$REMOTE" ]; then
             echo "⚠️ Git info not found or no upstream tracked. Make sure it's a git repo with main branch."
             exit 1
        fi

        if [ "$LOCAL" = "$REMOTE" ]; then
            echo "✅ Code is up to date."
        else
            if [ "$LOCAL" = "$BASE" ]; then
                echo "📥 New changes detected. Pulling..."
                git pull origin main
            else
                echo "⚠️ Diverged branches. Forcing reset to origin/main..."
                git reset --hard origin/main
            fi
            echo "🚀 Redeploying homepage configs..."
            bash "$SCRIPT_DIR/manager.sh" deploy
        fi
        ;;
    setup-git-sync)
        echo "⚙️ Setting up systemd timer for code git sync..."
        cat <<EOF | tee /etc/systemd/system/${GIT_SYNC_SERVICE}.service
[Unit]
Description=Homepage Git Sync
After=network.target

[Service]
Type=oneshot
User=root
WorkingDirectory=$SCRIPT_DIR
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=/usr/bin/bash $SCRIPT_DIR/manager.sh self-update
EOF
        cat <<EOF | tee /etc/systemd/system/${GIT_SYNC_SERVICE}.timer
[Unit]
Description=Homepage Git Sync Timer

[Timer]
OnBootSec=2min
OnUnitActiveSec=15min
Persistent=true

[Install]
WantedBy=timers.target
EOF
        systemctl daemon-reload
        systemctl enable --now ${GIT_SYNC_SERVICE}.timer
        echo "✅ Timer '${GIT_SYNC_SERVICE}' active (every 15 min)."
        ;;
    *)
        usage
        exit 1
        ;;
esac
