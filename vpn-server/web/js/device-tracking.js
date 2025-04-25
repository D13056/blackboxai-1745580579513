class DeviceTracker {
    constructor() {
        this.deviceInfo = {};
        this.securityChecks = {};
    }

    // Initialize device tracking
    async init() {
        await this.gatherDeviceInfo();
        this.setupSecurityMonitoring();
        this.startHeartbeat();
    }

    // Gather comprehensive device information
    async gatherDeviceInfo() {
        this.deviceInfo = {
            // Basic device info
            userAgent: navigator.userAgent,
            platform: navigator.platform,
            vendor: navigator.vendor,
            language: navigator.language,
            cookiesEnabled: navigator.cookieEnabled,
            doNotTrack: navigator.doNotTrack,
            
            // Screen properties
            screenResolution: {
                width: window.screen.width,
                height: window.screen.height,
                depth: window.screen.colorDepth,
                pixelRatio: window.devicePixelRatio
            },

            // Browser capabilities
            webGL: this.checkWebGL(),
            canvas: this.checkCanvas(),
            audio: this.checkAudioContext(),
            
            // Network information
            connection: this.getConnectionInfo(),
            
            // Time and location
            timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
            timezoneOffset: new Date().getTimezoneOffset(),
            
            // Hardware info
            cores: navigator.hardwareConcurrency || 'unknown',
            memory: navigator.deviceMemory || 'unknown',
            
            // Session info
            sessionId: this.generateSessionId(),
            timestamp: new Date().toISOString()
        };

        // Get geolocation if available
        if (navigator.geolocation) {
            try {
                const position = await this.getGeolocation();
                this.deviceInfo.geolocation = position;
            } catch (error) {
                console.warn('Geolocation not available:', error);
            }
        }

        return this.deviceInfo;
    }

    // Generate unique session ID
    generateSessionId() {
        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
            const r = Math.random() * 16 | 0;
            const v = c == 'x' ? r : (r & 0x3 | 0x8);
            return v.toString(16);
        });
    }

    // Check WebGL capabilities
    checkWebGL() {
        const canvas = document.createElement('canvas');
        const gl = canvas.getContext('webgl') || canvas.getContext('experimental-webgl');
        if (gl) {
            const info = {
                vendor: gl.getParameter(gl.VENDOR),
                renderer: gl.getParameter(gl.RENDERER),
                version: gl.getParameter(gl.VERSION)
            };
            gl.getExtension('WEBGL_debug_renderer_info');
            try {
                info.unmaskedVendor = gl.getParameter(0x9245); // UNMASKED_VENDOR_WEBGL
                info.unmaskedRenderer = gl.getParameter(0x9246); // UNMASKED_RENDERER_WEBGL
            } catch (e) {
                console.warn('WebGL debug info not available');
            }
            return info;
        }
        return null;
    }

    // Check Canvas capabilities
    checkCanvas() {
        const canvas = document.createElement('canvas');
        return {
            available: !!canvas.getContext,
            fingerprint: this.generateCanvasFingerprint(canvas)
        };
    }

    // Generate canvas fingerprint
    generateCanvasFingerprint(canvas) {
        const ctx = canvas.getContext('2d');
        if (!ctx) return null;

        // Draw various shapes and text
        ctx.textBaseline = "top";
        ctx.font = "14px 'Arial'";
        ctx.textBaseline = "alphabetic";
        ctx.fillStyle = "#f60";
        ctx.fillRect(125,1,62,20);
        ctx.fillStyle = "#069";
        ctx.fillText("DeviceTracker", 2, 15);
        ctx.fillStyle = "rgba(102, 204, 0, 0.7)";
        ctx.fillText("Fingerprint", 4, 17);

        return canvas.toDataURL();
    }

    // Check AudioContext capabilities
    checkAudioContext() {
        try {
            const AudioContext = window.AudioContext || window.webkitAudioContext;
            const ctx = new AudioContext();
            return {
                available: true,
                sampleRate: ctx.sampleRate,
                state: ctx.state
            };
        } catch (e) {
            return { available: false };
        }
    }

    // Get network connection information
    getConnectionInfo() {
        const connection = navigator.connection || navigator.mozConnection || navigator.webkitConnection;
        if (connection) {
            return {
                type: connection.type,
                effectiveType: connection.effectiveType,
                downlinkMax: connection.downlinkMax,
                downlink: connection.downlink,
                rtt: connection.rtt,
                saveData: connection.saveData
            };
        }
        return null;
    }

    // Get geolocation
    getGeolocation() {
        return new Promise((resolve, reject) => {
            navigator.geolocation.getCurrentPosition(
                position => resolve({
                    latitude: position.coords.latitude,
                    longitude: position.coords.longitude,
                    accuracy: position.coords.accuracy
                }),
                error => reject(error)
            );
        });
    }

    // Setup security monitoring
    setupSecurityMonitoring() {
        this.securityChecks = {
            lastActivity: new Date(),
            suspiciousActivities: [],
            failedAttempts: 0
        };

        // Monitor for suspicious activities
        this.monitorBrowserEvents();
        this.monitorNetworkActivity();
        this.detectVPNChanges();
    }

    // Monitor browser events for suspicious activity
    monitorBrowserEvents() {
        // Monitor visibility changes
        document.addEventListener('visibilitychange', () => {
            this.logActivity('visibility_change', {
                hidden: document.hidden,
                timestamp: new Date()
            });
        });

        // Monitor focus changes
        window.addEventListener('focus', () => {
            this.logActivity('window_focus', {
                type: 'focus',
                timestamp: new Date()
            });
        });

        window.addEventListener('blur', () => {
            this.logActivity('window_blur', {
                type: 'blur',
                timestamp: new Date()
            });
        });

        // Monitor storage changes
        window.addEventListener('storage', (e) => {
            this.logActivity('storage_change', {
                key: e.key,
                oldValue: e.oldValue,
                newValue: e.newValue,
                timestamp: new Date()
            });
        });
    }

    // Monitor network activity
    monitorNetworkActivity() {
        // Monitor online/offline status
        window.addEventListener('online', () => {
            this.logActivity('network_status', {
                status: 'online',
                timestamp: new Date()
            });
        });

        window.addEventListener('offline', () => {
            this.logActivity('network_status', {
                status: 'offline',
                timestamp: new Date()
            });
        });

        // Monitor connection changes
        if (navigator.connection) {
            navigator.connection.addEventListener('change', () => {
                this.logActivity('connection_change', {
                    connection: this.getConnectionInfo(),
                    timestamp: new Date()
                });
            });
        }
    }

    // Detect VPN changes
    detectVPNChanges() {
        // Periodically check for IP and location changes
        setInterval(async () => {
            try {
                const currentInfo = await this.gatherDeviceInfo();
                this.compareDeviceInfo(currentInfo);
            } catch (error) {
                console.error('Error detecting changes:', error);
            }
        }, 30000); // Check every 30 seconds
    }

    // Compare device info for changes
    compareDeviceInfo(newInfo) {
        const changes = [];
        
        // Compare relevant fields
        if (this.deviceInfo.connection?.type !== newInfo.connection?.type) {
            changes.push({
                type: 'connection_type_change',
                old: this.deviceInfo.connection?.type,
                new: newInfo.connection?.type
            });
        }

        if (this.deviceInfo.geolocation?.latitude !== newInfo.geolocation?.latitude ||
            this.deviceInfo.geolocation?.longitude !== newInfo.geolocation?.longitude) {
            changes.push({
                type: 'location_change',
                old: this.deviceInfo.geolocation,
                new: newInfo.geolocation
            });
        }

        // Log significant changes
        if (changes.length > 0) {
            this.logActivity('device_changes', {
                changes,
                timestamp: new Date()
            });
        }
    }

    // Log security-related activity
    logActivity(type, data) {
        const activity = {
            type,
            data,
            deviceId: this.deviceInfo.sessionId,
            timestamp: new Date()
        };

        // Send to server
        this.sendToServer('/api/security/log', activity);

        // Store locally
        this.securityChecks.suspiciousActivities.push(activity);
        
        // Cleanup old activities
        if (this.securityChecks.suspiciousActivities.length > 100) {
            this.securityChecks.suspiciousActivities.shift();
        }
    }

    // Send heartbeat to server
    startHeartbeat() {
        setInterval(() => {
            this.sendToServer('/api/device/heartbeat', {
                deviceId: this.deviceInfo.sessionId,
                timestamp: new Date(),
                status: 'active'
            });
        }, 60000); // Every minute
    }

    // Send data to server
    async sendToServer(endpoint, data) {
        try {
            const response = await fetch(endpoint, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(data)
            });

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            return await response.json();
        } catch (error) {
            console.error('Error sending data to server:', error);
            // Store failed requests for retry
            this.queueFailedRequest(endpoint, data);
        }
    }

    // Queue failed requests for retry
    queueFailedRequest(endpoint, data) {
        const failedRequests = JSON.parse(localStorage.getItem('failedRequests') || '[]');
        failedRequests.push({
            endpoint,
            data,
            timestamp: new Date()
        });
        localStorage.setItem('failedRequests', JSON.stringify(failedRequests));
    }

    // Retry failed requests
    async retryFailedRequests() {
        const failedRequests = JSON.parse(localStorage.getItem('failedRequests') || '[]');
        const remainingRequests = [];

        for (const request of failedRequests) {
            try {
                await this.sendToServer(request.endpoint, request.data);
            } catch (error) {
                if (new Date() - new Date(request.timestamp) < 24 * 60 * 60 * 1000) { // Keep requests less than 24h old
                    remainingRequests.push(request);
                }
            }
        }

        localStorage.setItem('failedRequests', JSON.stringify(remainingRequests));
    }
}

// Initialize device tracking
const deviceTracker = new DeviceTracker();
deviceTracker.init().catch(console.error);

// Export for use in other modules
export default deviceTracker;
