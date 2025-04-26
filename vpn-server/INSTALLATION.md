# One-Time Installation Guide for Ubuntu Server

## System Requirements
- Ubuntu Server 20.04 LTS or higher
- Minimum 2GB RAM
- 20GB free disk space

## Installation Steps

### 1. Update System Packages
```bash
sudo apt update && sudo apt upgrade -y
```

### 2. Install Required Dependencies
```bash
# Install essential tools
sudo apt install -y curl wget git

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install Go 1.21
wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc

# Install Redis (if not using Docker)
sudo apt install -y redis-server

# Install SQLite3
sudo apt install -y sqlite3

# Install Node.js and npm (for web interface development)
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs
```

### 3. Clone and Setup VPN Server
```bash
# Clone repository
git clone https://github.com/yourusername/vpn-server.git
cd vpn-server

# Copy configuration
cp config/config.example.yml config/config.yml

# Initialize database
sqlite3 data/vpn.db < database/schema.sql

# Create directories for Docker volumes
mkdir -p data cert fail2ban
```

### 4. Start Services

#### Option 1: Using Docker (Recommended)
```bash
# Build and start services
docker-compose up -d

# Check services status
docker-compose ps
```

#### Option 2: Manual Installation
```bash
# Install Go dependencies
go mod download

# Build the application
go build

# Start the VPN server
./vpn-server
```

### 5. Verify Installation
```bash
# Check if services are running
curl http://localhost:2053/api/monitor/status

# Check Docker containers (if using Docker)
docker-compose ps
```

### 6. Additional Security Setup
```bash
# Configure firewall
sudo ufw allow 2053/tcp
sudo ufw allow 443/tcp
sudo ufw enable

# Set proper permissions
sudo chown -R $USER:$USER /etc/x-ui
sudo chmod -R 755 /etc/x-ui
```

## Post-Installation Steps

1. Edit the configuration file at `config/config.yml` with your specific settings
2. Set up SSL certificates in the `cert` directory
3. Configure fail2ban rules in the `fail2ban` directory
4. Access the web interface at `https://your-server-ip:2053`

## Troubleshooting

### Check Logs
```bash
# Docker logs
docker-compose logs

# Service logs
journalctl -u vpn-server -f
```

### Common Issues

1. If port 2053 is already in use:
```bash
sudo lsof -i :2053
sudo kill -9 <PID>
```

2. If Docker fails to start:
```bash
systemctl status docker
journalctl -u docker
```

3. If Redis connection fails:
```bash
redis-cli ping
systemctl status redis
