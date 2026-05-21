# Proxmox Homepage

This repository contains the public configuration for the Homepage instance hosted on my Proxmox LXC. Sensitive information such as passwords, URLs, and tokens has been extracted using environment variables to keep the repository completely public and secure.

## Structure

The configuration uses a template system (`*.yaml.template`). Upon deployment, real values are injected from a local `.env` file, and the final `.yaml` files are generated in the LXC destination folder (`/opt/homepage/config/`).

## LXC Deployment (Production)

1. **Clone Repository**:
   ```bash
   git clone https://github.com/alpargatagazer/proxmox-homepage.git
   cd proxmox-homepage
   ```

2. **Configure Secrets**:
   ```bash
   cp .env.example .env
   ```
   Fill in `.env` with the correct IPs and credentials (ensure values are quoted if they contain special characters).

3. **Deploy Configuration**:
   ```bash
   ./manager.sh deploy
   ```
   This will generate the corresponding `.yaml` files and copy them to `/opt/homepage/config/`.

4. **Git Automation (Auto-Update)**:
   You can configure a systemd timer to pull from `main` and update the configs automatically every 15 minutes:
   ```bash
   ./manager.sh setup-git-sync
   ```

## Local Testing (Development)

If you want to visualize the homepage or test widgets on your own machine (using Docker):

1. **Configure Secrets**: Ensure your `.env` file is filled in.
2. **Start Local Environment**:
   ```bash
   ./manager.sh test-local
   ```
3. Visit [http://localhost:3000](http://localhost:3000)
4. **Stop Local Environment**:
   ```bash
   ./manager.sh test-down
   ```
