package main

import (
	"context"
	"database/sql"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/go-redis/redis/v8"
	"github.com/gorilla/mux"
	_ "github.com/mattn/go-sqlite3"
	"gopkg.in/yaml.v2"

	"vpn-server/api"
)

// Config represents the application configuration
type Config struct {
	Server struct {
		Port int    `yaml:"port"`
		Host string `yaml:"host"`
		SSL  struct {
			Enabled  bool   `yaml:"enabled"`
			CertFile string `yaml:"cert_file"`
			KeyFile  string `yaml:"key_file"`
		} `yaml:"ssl"`
	} `yaml:"server"`

	Database struct {
		Type string `yaml:"type"`
		Path string `yaml:"path"`
	} `yaml:"database"`

	Redis struct {
		Host     string `yaml:"host"`
		Port     int    `yaml:"port"`
		Password string `yaml:"password"`
		DB       int    `yaml:"db"`
	} `yaml:"redis"`

	Security struct {
		SessionTimeout int    `yaml:"session_timeout"`
		JWTSecret     string `yaml:"jwt_secret"`
		Fail2Ban      struct {
			Enabled  bool  `yaml:"enabled"`
			MaxRetry int   `yaml:"max_retry"`
			BanTime  int64 `yaml:"ban_time"`
		} `yaml:"fail2ban"`
	} `yaml:"security"`

	DeviceTracking struct {
		Enabled       bool     `yaml:"enabled"`
		StoreDetails []string `yaml:"store_details"`
		Suspicious   struct {
			MaxDevicesPerUser int      `yaml:"max_devices_per_user"`
			NotifyOnNew      bool     `yaml:"notify_on_new_device"`
			BlockSuspicious  bool     `yaml:"block_suspicious_ips"`
			GeoFencing      struct {
				Enabled         bool     `yaml:"enabled"`
				AllowedCountries []string `yaml:"allowed_countries"`
				BlockedCountries []string `yaml:"blocked_countries"`
			} `yaml:"geo_fencing"`
		} `yaml:"suspicious_activity"`
	} `yaml:"device_tracking"`
}

var (
	configPath = flag.String("config", "config/config.yml", "path to config file")
	config     Config
)

func main() {
	flag.Parse()

	// Load configuration
	if err := loadConfig(*configPath); err != nil {
		log.Fatalf("Error loading config: %v", err)
	}

	// Initialize database
	db, err := initDatabase()
	if err != nil {
		log.Fatalf("Error initializing database: %v", err)
	}
	defer db.Close()

	// Initialize Redis
	rdb := initRedis()
	defer rdb.Close()

	// Initialize router
	router := mux.NewRouter()

	// Initialize API handlers
	deviceHandler := api.NewDeviceHandler(db, rdb)
	deviceHandler.RegisterRoutes(router)

	// Setup middleware
	router.Use(loggingMiddleware)
	router.Use(securityMiddleware)
	router.Use(deviceTrackingMiddleware)

	// Setup static file serving with correct MIME types
	fs := http.FileServer(http.Dir("web"))
	router.PathPrefix("/").HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Set appropriate MIME types
		switch {
		case strings.HasSuffix(r.URL.Path, ".css"):
			w.Header().Set("Content-Type", "text/css")
		case strings.HasSuffix(r.URL.Path, ".js"):
			w.Header().Set("Content-Type", "application/javascript")
		case strings.HasSuffix(r.URL.Path, ".woff2"):
			w.Header().Set("Content-Type", "font/woff2")
		case strings.HasSuffix(r.URL.Path, ".woff"):
			w.Header().Set("Content-Type", "font/woff")
		case strings.HasSuffix(r.URL.Path, ".ttf"):
			w.Header().Set("Content-Type", "font/ttf")
		}
		fs.ServeHTTP(w, r)
	})

	// Create server
	srv := &http.Server{
		Addr:         fmt.Sprintf("%s:%d", config.Server.Host, config.Server.Port),
		Handler:      router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Start server
	go func() {
		log.Printf("Starting server on %s", srv.Addr)
		var err error
		if config.Server.SSL.Enabled {
			err = srv.ListenAndServeTLS(config.Server.SSL.CertFile, config.Server.SSL.KeyFile)
		} else {
			err = srv.ListenAndServe()
		}
		if err != nil && err != http.ErrServerClosed {
			log.Fatalf("Error starting server: %v", err)
		}
	}()

	// Wait for interrupt signal
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)
	<-c

	// Graceful shutdown
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Printf("Error during server shutdown: %v", err)
	}
	log.Println("Server gracefully stopped")
}

func loadConfig(path string) error {
	file, err := os.Open(path)
	if err != nil {
		return fmt.Errorf("error opening config file: %v", err)
	}
	defer file.Close()

	decoder := yaml.NewDecoder(file)
	if err := decoder.Decode(&config); err != nil {
		return fmt.Errorf("error decoding config file: %v", err)
	}

	return nil
}

func initDatabase() (*sql.DB, error) {
	db, err := sql.Open(config.Database.Type, config.Database.Path)
	if err != nil {
		return nil, fmt.Errorf("error opening database: %v", err)
	}

	// Initialize schema
	schemaFile, err := os.ReadFile("database/schema.sql")
	if err != nil {
		return nil, fmt.Errorf("error reading schema file: %v", err)
	}

	if _, err := db.Exec(string(schemaFile)); err != nil {
		return nil, fmt.Errorf("error initializing database schema: %v", err)
	}

	return db, nil
}

func initRedis() *redis.Client {
	rdb := redis.NewClient(&redis.Options{
		Addr:     fmt.Sprintf("%s:%d", config.Redis.Host, config.Redis.Port),
		Password: config.Redis.Password,
		DB:       config.Redis.DB,
	})

	return rdb
}

func loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		log.Printf(
			"%s %s %s %v",
			r.Method,
			r.RequestURI,
			r.RemoteAddr,
			time.Since(start),
		)
	})
}

func securityMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Set security headers
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-XSS-Protection", "1; mode=block")
		// In development, allow all resources
		if os.Getenv("ENV") != "production" {
			w.Header().Set("Content-Security-Policy", "default-src * 'unsafe-inline' 'unsafe-eval' data: blob:;")
		} else {
			w.Header().Set("Content-Security-Policy", "default-src 'self' 'unsafe-inline' fonts.googleapis.com cdnjs.cloudflare.com cdn.jsdelivr.net fonts.gstatic.com www.gravatar.com; img-src 'self' www.gravatar.com data:; style-src 'self' 'unsafe-inline' fonts.googleapis.com cdnjs.cloudflare.com; font-src 'self' fonts.gstatic.com cdnjs.cloudflare.com; script-src 'self' 'unsafe-inline' cdn.jsdelivr.net cdnjs.cloudflare.com")
		}
		w.Header().Set("Referrer-Policy", "strict-origin-when-cross-origin")
		w.Header().Set("Strict-Transport-Security", "max-age=31536000; includeSubDomains")

		next.ServeHTTP(w, r)
	})
}

func deviceTrackingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if config.DeviceTracking.Enabled {
			// Extract and store device information
			deviceInfo := extractDeviceInfo(r)
			storeDeviceInfo(deviceInfo)

			// Check for suspicious activity
			if isSuspiciousActivity(deviceInfo) {
				logSecurityEvent(deviceInfo)
				if config.DeviceTracking.Suspicious.BlockSuspicious {
					http.Error(w, "Access denied", http.StatusForbidden)
					return
				}
			}
		}

		next.ServeHTTP(w, r)
	})
}

func extractDeviceInfo(r *http.Request) map[string]interface{} {
	return map[string]interface{}{
		"ip_address": r.RemoteAddr,
		"user_agent": r.UserAgent(),
		"headers":    r.Header,
		"timestamp": time.Now(),
	}
}

func storeDeviceInfo(info map[string]interface{}) {
	// Implement device info storage logic
}

func isSuspiciousActivity(info map[string]interface{}) bool {
	// Implement suspicious activity detection logic
	return false
}

func logSecurityEvent(info map[string]interface{}) {
	// Implement security event logging logic
}
