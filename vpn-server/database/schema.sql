-- Device tracking and security tables

-- Devices table stores information about connected devices
CREATE TABLE IF NOT EXISTS devices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id VARCHAR(36) NOT NULL UNIQUE,
    user_id INTEGER,
    user_agent TEXT,
    platform VARCHAR(255),
    vendor VARCHAR(255),
    ip_address VARCHAR(45),
    mac_address VARCHAR(17),
    hostname VARCHAR(255),
    os_name VARCHAR(255),
    os_version VARCHAR(255),
    browser_name VARCHAR(255),
    browser_version VARCHAR(255),
    screen_resolution VARCHAR(50),
    timezone VARCHAR(100),
    language VARCHAR(50),
    is_authorized BOOLEAN DEFAULT false,
    is_blocked BOOLEAN DEFAULT false,
    last_seen TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Device locations table stores geographical information
CREATE TABLE IF NOT EXISTS device_locations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id INTEGER NOT NULL,
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    country VARCHAR(2),
    region VARCHAR(255),
    city VARCHAR(255),
    isp VARCHAR(255),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE
);

-- Device connections table stores network connection information
CREATE TABLE IF NOT EXISTS device_connections (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id INTEGER NOT NULL,
    connection_type VARCHAR(50),
    effective_type VARCHAR(50),
    downlink DECIMAL(10,2),
    rtt INTEGER,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE
);

-- Security events table stores security-related events
CREATE TABLE IF NOT EXISTS security_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id INTEGER,
    user_id INTEGER,
    event_type VARCHAR(50) NOT NULL,
    severity VARCHAR(20) NOT NULL,
    ip_address VARCHAR(45),
    details TEXT,
    is_resolved BOOLEAN DEFAULT false,
    resolved_at TIMESTAMP,
    resolved_by INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE SET NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (resolved_by) REFERENCES users(id) ON DELETE SET NULL
);

-- Device authentication history
CREATE TABLE IF NOT EXISTS device_auth_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id INTEGER NOT NULL,
    user_id INTEGER,
    auth_type VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- Device verification codes for new device authorization
CREATE TABLE IF NOT EXISTS device_verification_codes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    code VARCHAR(6) NOT NULL,
    verification_type VARCHAR(20) NOT NULL,
    is_used BOOLEAN DEFAULT false,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Device blocking history
CREATE TABLE IF NOT EXISTS device_blocks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id INTEGER NOT NULL,
    blocked_by INTEGER,
    reason TEXT,
    is_active BOOLEAN DEFAULT true,
    unblocked_at TIMESTAMP,
    unblocked_by INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
    FOREIGN KEY (blocked_by) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (unblocked_by) REFERENCES users(id) ON DELETE SET NULL
);

-- Device activity logs
CREATE TABLE IF NOT EXISTS device_activity_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id INTEGER NOT NULL,
    user_id INTEGER,
    activity_type VARCHAR(50) NOT NULL,
    details TEXT,
    ip_address VARCHAR(45),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- Device anomaly detection rules
CREATE TABLE IF NOT EXISTS anomaly_rules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    rule_type VARCHAR(50) NOT NULL,
    conditions TEXT NOT NULL,
    severity VARCHAR(20) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Device anomaly detections
CREATE TABLE IF NOT EXISTS anomaly_detections (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id INTEGER NOT NULL,
    rule_id INTEGER NOT NULL,
    details TEXT,
    is_resolved BOOLEAN DEFAULT false,
    resolved_at TIMESTAMP,
    resolved_by INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
    FOREIGN KEY (rule_id) REFERENCES anomaly_rules(id) ON DELETE CASCADE,
    FOREIGN KEY (resolved_by) REFERENCES users(id) ON DELETE SET NULL
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_devices_session_id ON devices(session_id);
CREATE INDEX IF NOT EXISTS idx_devices_user_id ON devices(user_id);
CREATE INDEX IF NOT EXISTS idx_devices_ip_address ON devices(ip_address);
CREATE INDEX IF NOT EXISTS idx_devices_last_seen ON devices(last_seen);

CREATE INDEX IF NOT EXISTS idx_device_locations_device_id ON device_locations(device_id);
CREATE INDEX IF NOT EXISTS idx_device_locations_country ON device_locations(country);

CREATE INDEX IF NOT EXISTS idx_device_connections_device_id ON device_connections(device_id);
CREATE INDEX IF NOT EXISTS idx_device_connections_timestamp ON device_connections(timestamp);

CREATE INDEX IF NOT EXISTS idx_security_events_device_id ON security_events(device_id);
CREATE INDEX IF NOT EXISTS idx_security_events_user_id ON security_events(user_id);
CREATE INDEX IF NOT EXISTS idx_security_events_type ON security_events(event_type);
CREATE INDEX IF NOT EXISTS idx_security_events_created_at ON security_events(created_at);

CREATE INDEX IF NOT EXISTS idx_device_auth_history_device_id ON device_auth_history(device_id);
CREATE INDEX IF NOT EXISTS idx_device_auth_history_user_id ON device_auth_history(user_id);
CREATE INDEX IF NOT EXISTS idx_device_auth_history_created_at ON device_auth_history(created_at);

CREATE INDEX IF NOT EXISTS idx_device_verification_codes_device_id ON device_verification_codes(device_id);
CREATE INDEX IF NOT EXISTS idx_device_verification_codes_user_id ON device_verification_codes(user_id);
CREATE INDEX IF NOT EXISTS idx_device_verification_codes_code ON device_verification_codes(code);

CREATE INDEX IF NOT EXISTS idx_device_blocks_device_id ON device_blocks(device_id);
CREATE INDEX IF NOT EXISTS idx_device_blocks_is_active ON device_blocks(is_active);

CREATE INDEX IF NOT EXISTS idx_device_activity_logs_device_id ON device_activity_logs(device_id);
CREATE INDEX IF NOT EXISTS idx_device_activity_logs_user_id ON device_activity_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_device_activity_logs_created_at ON device_activity_logs(created_at);

CREATE INDEX IF NOT EXISTS idx_anomaly_detections_device_id ON anomaly_detections(device_id);
CREATE INDEX IF NOT EXISTS idx_anomaly_detections_rule_id ON anomaly_detections(rule_id);
CREATE INDEX IF NOT EXISTS idx_anomaly_detections_created_at ON anomaly_detections(created_at);

-- Create views for common queries
CREATE VIEW IF NOT EXISTS v_active_devices AS
SELECT d.*, dl.country, dl.city, dc.connection_type
FROM devices d
LEFT JOIN device_locations dl ON d.id = dl.device_id
LEFT JOIN device_connections dc ON d.id = dc.device_id
WHERE d.last_seen >= datetime('now', '-15 minutes')
AND d.is_blocked = false;

CREATE VIEW IF NOT EXISTS v_security_summary AS
SELECT 
    d.id as device_id,
    d.session_id,
    d.user_agent,
    d.ip_address,
    COUNT(DISTINCT se.id) as security_events_count,
    COUNT(DISTINCT ad.id) as anomaly_detections_count,
    MAX(se.created_at) as last_security_event,
    MAX(ad.created_at) as last_anomaly_detection
FROM devices d
LEFT JOIN security_events se ON d.id = se.device_id
LEFT JOIN anomaly_detections ad ON d.id = ad.device_id
GROUP BY d.id, d.session_id, d.user_agent, d.ip_address;

-- Create triggers for automatic updates
CREATE TRIGGER IF NOT EXISTS update_device_last_seen
AFTER INSERT ON device_activity_logs
BEGIN
    UPDATE devices 
    SET last_seen = NEW.created_at 
    WHERE id = NEW.device_id;
END;

CREATE TRIGGER IF NOT EXISTS log_device_block
AFTER UPDATE OF is_blocked ON devices
WHEN NEW.is_blocked = 1
BEGIN
    INSERT INTO device_blocks (device_id, reason)
    VALUES (NEW.id, 'Automatic block due to security policy');
END;
