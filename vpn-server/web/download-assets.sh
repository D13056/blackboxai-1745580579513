#!/bin/bash

# Create directories
mkdir -p assets/css
mkdir -p assets/js
mkdir -p assets/fonts

# Download Font Awesome CSS and fonts
wget https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0-beta3/css/all.min.css -O assets/css/font-awesome.min.css
wget https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0-beta3/webfonts/fa-solid-900.woff2 -O assets/fonts/fa-solid-900.woff2
wget https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0-beta3/webfonts/fa-regular-400.woff2 -O assets/fonts/fa-regular-400.woff2
wget https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0-beta3/webfonts/fa-brands-400.woff2 -O assets/fonts/fa-brands-400.woff2

# Download Inter font
wget https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap -O assets/css/inter.css

# Download Chart.js
wget https://cdn.jsdelivr.net/npm/chart.js -O assets/js/chart.min.js

# Update font paths in Font Awesome CSS
sed -i 's|../webfonts/|../fonts/|g' assets/css/font-awesome.min.css

echo "Assets downloaded successfully!"
