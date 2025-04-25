package api

import (
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"time"

	"github.com/go-redis/redis/v8"
	"github.com/gorilla/mux"
)

// DeviceInfo represents the device information collected from clients
type DeviceInfo struct {
	SessionID    string    `json:"sessionId"`
	UserAgent    string    `json:"userAgent"`
	Platform     string    `json:"platform"`
	Vendor       string    `json:"vendor"`
	IPAddress    string    `json:"ipAddress"`
	Location     Location  `json:"location,omitempty"`
	Connection   Connection `json:"connection"`
	LastSeen     time.Time `json:"lastSeen"`
	CreatedAt    time.Time `json:"createdAt"`
	IsAuthorized bool      `json:"isAuthorized"`
}

// Location represents geographical location data
type Location struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
	Country   string  `json:"country"`
	City      string  `json:"city"`
}

// Connection represents network connection information
type Connection struct {
	Type          string  `json:"type"`
	EffectiveType string  `json:"effectiveType"`
	Downlink      float64 `json:"downlink"`
	RTT           int     `json:"rtt"`
}

// SecurityEvent represents a security-related event
type SecurityEvent struct {
	Type      string    `json:"type"`
	DeviceID  string    `json:"deviceId"`
	UserID    string    `json:"userId"`
	IPAddress string    `json:"ipAddress"`
	Severity  string    `json:"severity"`
	Details   string    `json:"details"`
	Timestamp time.Time `json:"timestamp"`
}

// DeviceHandler handles device-related API endpoints
type DeviceHandler struct {
	db    *sql.DB
	redis *redis.Client
}

// NewDeviceHandler creates a new DeviceHandler instance
func NewDeviceHandler(db *sql.DB, redis *redis.Client) *DeviceHandler {
	return &DeviceHandler{
		db:    db,
		redis: redis,
	}
}

// RegisterRoutes registers the device-related API routes
func (h *DeviceHandler) RegisterRoutes(r *mux.Router) {
	r.HandleFunc("/api/device/register", h.RegisterDevice).Methods("POST")
	r.HandleFunc("/api/device/heartbeat", h.DeviceHeartbeat).Methods("POST")
	r.HandleFunc("/api/device/{id}", h.GetDevice).Methods("GET")
	r.HandleFunc("/api/device/{id}/authorize", h.AuthorizeDevice).Methods("POST")
	r.HandleFunc("/api/device/{id}/block", h.BlockDevice).Methods("POST")
	r.HandleFunc("/api/security/log", h.LogSecurityEvent).Methods("POST")
	r.HandleFunc("/api/security/events", h.GetSecurityEvents).Methods("GET")
}

// RegisterDevice handles new device registration
func (h *DeviceHandler) RegisterDevice(w http.ResponseWriter, r *http.Request) {
	var device DeviceInfo
	if err := json.NewDecoder(r.Body).Decode(&device); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// Set initial device properties
	device.CreatedAt = time.Now()
	device.LastSeen = time.Now()
	device.IPAddress = r.RemoteAddr

	// Enrich device info with geolocation
	if err := h.enrichDeviceInfo(&device); err != nil {
		log.Printf("Error enriching device info: %v", err)
	}

	// Check for suspicious patterns
	if h.isSuspiciousDevice(device) {
		h.logSecurityEvent(SecurityEvent{
			Type:      "suspicious_device",
			DeviceID:  device.SessionID,
			IPAddress: device.IPAddress,
			Severity:  "high",
			Details:   "Suspicious device pattern detected during registration",
			Timestamp: time.Now(),
		})
		device.IsAuthorized = false
	} else {
		device.IsAuthorized = true
	}

	// Store device info
	if err := h.storeDevice(device); err != nil {
		http.Error(w, "Error storing device info", http.StatusInternalServerError)
		return
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":     "success",
		"deviceId":   device.SessionID,
		"authorized": device.IsAuthorized,
	})
}

// DeviceHeartbeat handles device heartbeat updates
func (h *DeviceHandler) DeviceHeartbeat(w http.ResponseWriter, r *http.Request) {
	var heartbeat struct {
		DeviceID  string    `json:"deviceId"`
		Timestamp time.Time `json:"timestamp"`
		Status    string    `json:"status"`
	}

	if err := json.NewDecoder(r.Body).Decode(&heartbeat); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// Update device last seen time
	if err := h.updateDeviceLastSeen(heartbeat.DeviceID, heartbeat.Timestamp); err != nil {
		http.Error(w, "Error updating device status", http.StatusInternalServerError)
		return
	}

	// Check for anomalies
	if h.detectAnomalies(heartbeat.DeviceID, r.RemoteAddr) {
		h.logSecurityEvent(SecurityEvent{
			Type:      "anomaly_detected",
			DeviceID:  heartbeat.DeviceID,
			IPAddress: r.RemoteAddr,
			Severity:  "medium",
			Details:   "Anomalous behavior detected during heartbeat",
			Timestamp: time.Now(),
		})
	}

	w.WriteHeader(http.StatusOK)
}

// GetDevice retrieves device information
func (h *DeviceHandler) GetDevice(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	deviceID := vars["id"]

	device, err := h.getDeviceByID(deviceID)
	if err != nil {
		if err == sql.ErrNoRows {
			http.Error(w, "Device not found", http.StatusNotFound)
			return
		}
		http.Error(w, "Error retrieving device", http.StatusInternalServerError)
		return
	}

	json.NewEncoder(w).Encode(device)
}

// AuthorizeDevice handles device authorization
func (h *DeviceHandler) AuthorizeDevice(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	deviceID := vars["id"]

	if err := h.setDeviceAuthorization(deviceID, true); err != nil {
		http.Error(w, "Error authorizing device", http.StatusInternalServerError)
		return
	}

	h.logSecurityEvent(SecurityEvent{
		Type:      "device_authorized",
		DeviceID:  deviceID,
		IPAddress: r.RemoteAddr,
		Severity:  "info",
		Details:   "Device manually authorized",
		Timestamp: time.Now(),
	})

	w.WriteHeader(http.StatusOK)
}

// BlockDevice handles device blocking
func (h *DeviceHandler) BlockDevice(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	deviceID := vars["id"]

	if err := h.setDeviceAuthorization(deviceID, false); err != nil {
		http.Error(w, "Error blocking device", http.StatusInternalServerError)
		return
	}

	h.logSecurityEvent(SecurityEvent{
		Type:      "device_blocked",
		DeviceID:  deviceID,
		IPAddress: r.RemoteAddr,
		Severity:  "warning",
		Details:   "Device manually blocked",
		Timestamp: time.Now(),
	})

	w.WriteHeader(http.StatusOK)
}

// LogSecurityEvent handles security event logging
func (h *DeviceHandler) LogSecurityEvent(w http.ResponseWriter, r *http.Request) {
	var event SecurityEvent
	if err := json.NewDecoder(r.Body).Decode(&event); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	event.Timestamp = time.Now()
	event.IPAddress = r.RemoteAddr

	if err := h.logSecurityEvent(event); err != nil {
		http.Error(w, "Error logging security event", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
}

// GetSecurityEvents retrieves security events
func (h *DeviceHandler) GetSecurityEvents(w http.ResponseWriter, r *http.Request) {
	limit := 100 // Default limit
	if r.URL.Query().Get("limit") != "" {
		// Parse limit from query parameter
	}

	events, err := h.getSecurityEvents(limit)
	if err != nil {
		http.Error(w, "Error retrieving security events", http.StatusInternalServerError)
		return
	}

	json.NewEncoder(w).Encode(events)
}

// Helper functions

func (h *DeviceHandler) enrichDeviceInfo(device *DeviceInfo) error {
	// Implement geolocation lookup
	// Implement additional device info enrichment
	return nil
}

func (h *DeviceHandler) isSuspiciousDevice(device DeviceInfo) bool {
	// Implement device suspicion detection logic
	return false
}

func (h *DeviceHandler) storeDevice(device DeviceInfo) error {
	// Implement device storage logic
	return nil
}

func (h *DeviceHandler) updateDeviceLastSeen(deviceID string, timestamp time.Time) error {
	// Implement last seen update logic
	return nil
}

func (h *DeviceHandler) detectAnomalies(deviceID, ipAddress string) bool {
	// Implement anomaly detection logic
	return false
}

func (h *DeviceHandler) getDeviceByID(deviceID string) (*DeviceInfo, error) {
	// Implement device retrieval logic
	return nil, nil
}

func (h *DeviceHandler) setDeviceAuthorization(deviceID string, authorized bool) error {
	// Implement device authorization logic
	return nil
}

func (h *DeviceHandler) logSecurityEvent(event SecurityEvent) error {
	// Implement security event logging logic
	return nil
}

func (h *DeviceHandler) getSecurityEvents(limit int) ([]SecurityEvent, error) {
	// Implement security event retrieval logic
	return nil, nil
}
