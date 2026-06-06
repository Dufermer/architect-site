package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	_ "modernc.org/sqlite"
)

// ContactMessage represents a contact form submission
type ContactMessage struct {
	ID        int64  `json:"id,omitempty"`
	Name      string `json:"name"`
	Email     string `json:"email"`
	Message   string `json:"message"`
	Phone     string `json:"phone,omitempty"`
	CreatedAt string `json:"created_at,omitempty"`
}

// App holds dependencies
type App struct {
	DB *sql.DB
}

func main() {
	port := getEnv("PORT", "8080")
	dbPath := getEnv("DB_PATH", "./architect.db")

	// Open database
	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		log.Fatalf("Failed to open database: %v", err)
	}
	defer db.Close()

	// Configure connection pool
	db.SetMaxOpenConns(1) // SQLite only supports one writer
	db.SetMaxIdleConns(1)
	db.SetConnMaxLifetime(time.Hour)

	// Create tables
	if err := migrate(db); err != nil {
		log.Fatalf("Failed to migrate database: %v", err)
	}

	app := &App{DB: db}

	// Setup router
	r := chi.NewRouter()

	// Middleware
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Timeout(30 * time.Second))
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Content-Type", "X-Request-ID"},
		AllowCredentials: false,
		MaxAge:           300,
	}))

	// Routes
	r.Get("/api/health", app.healthCheck)
	r.Post("/api/contact", app.submitContact)

	// API info
	r.Route("/api", func(r chi.Router) {
		r.Get("/", app.apiInfo)
	})

	addr := fmt.Sprintf(":%s", port)
	log.Printf("🚀 Architect API server starting on %s", addr)
	log.Printf("   Database: %s", dbPath)
	log.Printf("   Endpoints:")
	log.Printf("   - GET  /api/health")
	log.Printf("   - GET  /api")
	log.Printf("   - POST /api/contact")

	if err := http.ListenAndServe(addr, r); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}

func migrate(db *sql.DB) error {
	query := `
	CREATE TABLE IF NOT EXISTS contacts (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		name TEXT NOT NULL,
		email TEXT NOT NULL,
		message TEXT NOT NULL,
		phone TEXT DEFAULT '',
		created_at TEXT NOT NULL DEFAULT (datetime('now'))
	);
	`
	_, err := db.Exec(query)
	return err
}

func (app *App) healthCheck(w http.ResponseWriter, r *http.Request) {
	// Check database connectivity
	err := app.DB.Ping()
	if err != nil {
		respondJSON(w, http.StatusServiceUnavailable, map[string]string{
			"status":  "degraded",
			"db":      "unreachable",
			"error":   err.Error(),
		})
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{
		"status":    "ok",
		"service":   "architect-api",
		"version":   "1.0.0",
		"timestamp": time.Now().UTC().Format(time.RFC3339),
	})
}

func (app *App) apiInfo(w http.ResponseWriter, r *http.Request) {
	respondJSON(w, http.StatusOK, map[string]interface{}{
		"service": "Architect API",
		"version": "1.0.0",
		"endpoints": []map[string]string{
			{"path": "/api/health", "method": "GET", "description": "Health check"},
			{"path": "/api/contact", "method": "POST", "description": "Submit contact form"},
			{"path": "/api", "method": "GET", "description": "API info"},
		},
	})
}

func (app *App) submitContact(w http.ResponseWriter, r *http.Request) {
	var msg ContactMessage

	if err := json.NewDecoder(r.Body).Decode(&msg); err != nil {
		respondJSON(w, http.StatusBadRequest, map[string]string{
			"error": "invalid JSON body",
		})
		return
	}

	// Validate required fields
	if msg.Name == "" || msg.Email == "" || msg.Message == "" {
		respondJSON(w, http.StatusBadRequest, map[string]string{
			"error": "name, email, and message are required",
		})
		return
	}

	// Insert into database
	result, err := app.DB.Exec(
		"INSERT INTO contacts (name, email, message, phone) VALUES (?, ?, ?, ?)",
		msg.Name, msg.Email, msg.Message, msg.Phone,
	)
	if err != nil {
		log.Printf("Error saving contact: %v", err)
		respondJSON(w, http.StatusInternalServerError, map[string]string{
			"error": "failed to save message",
		})
		return
	}

	id, _ := result.LastInsertId()
	msg.ID = id
	msg.CreatedAt = time.Now().UTC().Format(time.RFC3339)

	respondJSON(w, http.StatusCreated, map[string]interface{}{
		"success": true,
		"id":      id,
		"message": "Thank you! Your message has been received.",
	})
}

func respondJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

func getEnv(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}
