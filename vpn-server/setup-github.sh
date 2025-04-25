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

# Check if git is installed
if ! command -v git &> /dev/null; then
    print_message "Git is not installed. Installing..." "$YELLOW"
    sudo apt-get update
    sudo apt-get install -y git
fi

# Initialize git repository if not already initialized
if [ ! -d ".git" ]; then
    print_message "Initializing git repository..." "$YELLOW"
    git init
fi

# Create .gitignore
print_message "Creating .gitignore..." "$YELLOW"
cat > .gitignore << EOL
# Binary files
vpn-server
*.exe
*.dll
*.so
*.dylib

# Database
data/*.db
*.db-journal

# Config files
config/config.yml

# Log files
*.log

# Environment variables
.env

# IDE specific files
.idea/
.vscode/
*.swp
*.swo

# OS specific files
.DS_Store
Thumbs.db

# Temporary files
tmp/
temp/

# Certificates
*.pem
*.key
*.crt

# Dependencies
vendor/
EOL

# Make scripts executable
chmod +x install.sh
chmod +x setup-github.sh

# Add all files
git add .

# Initial commit
git commit -m "Initial commit: VPN Server with enhanced security and device tracking"

print_message "Now, create a new repository on GitHub and run the following commands:" "$GREEN"
print_message "git remote add origin https://github.com/yourusername/vpn-server.git" "$YELLOW"
print_message "git branch -M main" "$YELLOW"
print_message "git push -u origin main" "$YELLOW"

print_message "\nTo install on a new server, run:" "$GREEN"
print_message "wget https://raw.githubusercontent.com/yourusername/vpn-server/main/install.sh" "$YELLOW"
print_message "chmod +x install.sh" "$YELLOW"
print_message "sudo ./install.sh" "$YELLOW"
