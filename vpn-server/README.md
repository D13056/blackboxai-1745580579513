# Advanced Customizable Secure VPN Server

A highly secure and customizable VPN server built on top of the 3x-ui project with enhanced security features, device tracking, and monitoring capabilities.

## Features

### Enhanced Security
- Advanced device tracking and fingerprinting
- Suspicious activity detection
- Geolocation-based access control
- Multi-factor authentication support
- Real-time security alerts
- IP and device blocking capabilities
- Fail2ban integration
- SSL/TLS encryption

### Device Management
- Comprehensive device information tracking
  - Hardware details
  - Operating system
  - Browser information
  - Screen resolution
  - Network details
  - Location data
- Device authorization workflow
- Connection history and analytics
- Device usage patterns monitoring
- Anomaly detection
- Device fingerprinting
- MAC address tracking
- Connection type monitoring

### Monitoring & Analytics
- Real-time traffic monitoring
- Bandwidth usage tracking
- Connection statistics
- Security event logging
- Performance metrics
- Custom alert configurations
- Traffic pattern analysis
- Anomaly detection
- Resource usage monitoring

### User Management
- Role-based access control
- User activity monitoring
- Traffic quota management
- Device limit enforcement
- Usage statistics
- Session management
- Access logs

## Prerequisites

- Go 1.21 or higher
- Redis
- SQLite3
- Node.js (for web interface development)
- Docker (optional)

## Installation

For detailed installation instructions on Ubuntu Server, please refer to [INSTALLATION.md](INSTALLATION.md).

For quick installation using Docker:

1. Build the Docker image:
```bash
docker-compose build
```

2. Start the services:
```bash
docker-compose up -d
```

## Configuration

The configuration file (`config.yml`) includes settings for:

### Server Configuration
```yaml
server:
  port: 2053
  host: "0.0.0.0"
  ssl:
    enabled: true
    cert_file: "/path/to/cert.pem"
    key_file: "/path/to/key.pem"
```

### Security Settings
```yaml
security:
  session_timeout: 7200
  jwt_secret: "your-secret-key"
  fail2ban:
    enabled: true
    max_retry: 5
    ban_time: 3600
```

### Device Tracking Options
```yaml
device_tracking:
  enabled: true
  store_details:
    - user_agent
    - ip_address
    - device_type
    - operating_system
    - browser
    - screen_resolution
    - timezone
    - language
    - mac_address
  suspicious_activity:
    max_devices_per_user: 3
    notify_on_new_device: true
    block_suspicious_ips: true
    geo_fencing:
      enabled: true
      allowed_countries: []
      blocked_countries: []
```

## Security Features

### Device Tracking
- Real-time device monitoring
- Device fingerprinting
- Connection pattern analysis
- Suspicious activity detection
- Geolocation tracking
- Network monitoring
- Device history logging

### Authentication & Authorization
- Multi-factor authentication
- Device-based authentication
- Session management
- Access control lists
- IP-based restrictions
- Geolocation-based access control
- Device verification workflow

### Monitoring & Alerts
- Real-time traffic monitoring
- Security event logging
- Performance monitoring
- Resource usage tracking
- Custom alert configurations
- Notification system
- Audit logging

### Protection Mechanisms
- Fail2ban integration
- DDoS protection
- Rate limiting
- IP blocking
- Device blocking
- Suspicious activity detection
- Anomaly detection
- Traffic pattern analysis

## API Documentation

### Device Management Endpoints
```
POST /api/device/register      - Register a new device
POST /api/device/heartbeat     - Device heartbeat update
GET  /api/device/{id}         - Get device information
POST /api/device/{id}/authorize - Authorize device
POST /api/device/{id}/block    - Block device
```

### Security Endpoints
```
POST /api/security/log        - Log security event
GET  /api/security/events     - Get security events
POST /api/security/block      - Block IP/device
GET  /api/security/status     - Get security status
```

### Monitoring Endpoints
```
GET  /api/monitor/traffic     - Get traffic statistics
GET  /api/monitor/devices     - Get connected devices
GET  /api/monitor/alerts      - Get security alerts
GET  /api/monitor/performance - Get system performance
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the GPL-3.0 License - see the LICENSE file for details.

## Acknowledgments

- Based on the [3x-ui](https://github.com/MHSanaei/3x-ui) project
- Enhanced with additional security features and device tracking capabilities
