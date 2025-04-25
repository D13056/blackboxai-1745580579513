#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print colored message
print_message() {
    echo -e "${2}${1}${NC}"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_message "Please run as root" "$RED"
    exit 1
fi

print_message "Starting VPN Server installation..." "$GREEN"

# Update system
print_message "Updating system packages..." "$YELLOW"
apt-get update
apt-get upgrade -y

# Install required packages
print_message "Installing required packages..." "$YELLOW"
apt-get install -y \
    curl \
    wget \
    git \
    sqlite3 \
    redis-server \
    fail2ban \
    certbot \
    nginx \
    supervisor \
    nodejs \
    npm
    
# Install Tailwind CSS
print_message "Installing Tailwind CSS..." "$YELLOW"
mkdir -p $INSTALL_DIR/web/css
cd $INSTALL_DIR/web
npm init -y
npm install tailwindcss
npx tailwindcss init
cat > tailwind.config.js << EOL
module.exports = {
  content: ["./**/*.{html,js}"],
  theme: {
    extend: {},
  },
  plugins: [],
}
EOL

# Create CSS file
cat > css/input.css << EOL
@tailwind base;
@tailwind components;
@tailwind utilities;
EOL

# Build Tailwind CSS
npx tailwindcss -i css/input.css -o css/styles.css --minify

# Install Go
print_message "Installing Go..." "$YELLOW"
GO_VERSION="1.21.5"
wget https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz
tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
rm go${GO_VERSION}.linux-amd64.tar.gz

# Set Go environment variables
echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
echo 'export GOPATH=$HOME/go' >> /etc/profile
source /etc/profile

# Create installation directory
print_message "Creating installation directory..." "$YELLOW"
INSTALL_DIR="/opt/vpn-server"
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# Clone repository
print_message "Cloning repository..." "$YELLOW"
git clone https://github.com/yourusername/vpn-server.git .

# Initialize database
print_message "Initializing database..." "$YELLOW"
mkdir -p data
sqlite3 data/vpn.db < database/schema.sql

# Set up configuration
print_message "Setting up configuration..." "$YELLOW"
cp config/config.example.yml config/config.yml

# Build application
print_message "Building application..." "$YELLOW"
go mod download
go build -o vpn-server

# Set up systemd service
print_message "Setting up systemd service..." "$YELLOW"
cat > /etc/systemd/system/vpn-server.service << EOL
[Unit]
Description=VPN Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/vpn-server
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOL

# Set up fail2ban
print_message "Configuring fail2ban..." "$YELLOW"
cat > /etc/fail2ban/jail.d/vpn-server.conf << EOL
[vpn-server]
enabled = true
port = 8000
filter = vpn-server
logpath = /var/log/vpn-server.log
maxretry = 5
bantime = 3600
findtime = 3600
EOL

cat > /etc/fail2ban/filter.d/vpn-server.conf << EOL
[Definition]
failregex = ^.*Failed login attempt from <HOST>.*$
ignoreregex =
EOL

# Set up nginx reverse proxy
print_message "Configuring nginx..." "$YELLOW"
cat > /etc/nginx/sites-available/vpn-server << EOL
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOL

ln -sf /etc/nginx/sites-available/vpn-server /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Start services
print_message "Starting services..." "$YELLOW"
systemctl daemon-reload
systemctl enable vpn-server
systemctl enable redis-server
systemctl enable fail2ban
systemctl enable nginx

systemctl restart redis-server
systemctl restart fail2ban
systemctl restart nginx
systemctl start vpn-server

# Set up automatic updates
print_message "Setting up automatic updates..." "$YELLOW"
cat > /etc/cron.daily/vpn-server-update << EOL
#!/bin/bash
cd $INSTALL_DIR
git pull
go build -o vpn-server
systemctl restart vpn-server
EOL

chmod +x /etc/cron.daily/vpn-server-update

# Final message
print_message "Installation completed successfully!" "$GREEN"
print_message "The VPN server is now running on port 8000" "$GREEN"
print_message "You can access the web interface at http://YOUR_SERVER_IP:8000" "$GREEN"
print_message "Please update the config.yml file with your settings" "$YELLOW"
print_message "To view logs: journalctl -u vpn-server -f" "$YELLOW"

# Print current status
systemctl status vpn-server --no-pager
