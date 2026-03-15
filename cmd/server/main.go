package main

import (
	"log"
	"net/http"
	"time"
	"vpn-provider/internal/auth"
	"vpn-provider/internal/db"
	"vpn-provider/internal/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

var database *gorm.DB

func main() {
	// Initialize Database (Using SQLite for POC/local development ease, but code supports Postgres)
	// For production, these would come from env variables

	log.Println("Initializing database configuration...")
	dbConfig := db.Config{
		Host:     "localhost",
		Port:     5432,
		User:     "postgres",
		Password: "password",
		DBName:   "vpn",
		SSLMode:  "disable",
	}

	var err error
	database, err = db.InitDB(dbConfig)
	if err != nil {
		log.Fatalf("Could not connect to database: %v", err)
	}

	r := gin.Default()

	// Serve the frontend UI for testing
	r.Static("/ui", "./frontend")

	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	authGroup := r.Group("/auth")
	{
		authGroup.POST("/register", registerHandler)
		authGroup.POST("/login", loginHandler)
	}

	userGroup := r.Group("/user")
	userGroup.Use(authMiddleware())
	{
		userGroup.POST("/connect", connectHandler)
		userGroup.GET("/config/:peerID", downloadConfigHandler)
	}

	nodeGroup := r.Group("/nodes")
	// In production, use a middleware to verify a secret shared key for agents
	{
		nodeGroup.POST("/register", registerNodeHandler)
		nodeGroup.POST("/heartbeat", heartbeatNodeHandler)
		nodeGroup.GET("/:id/peers", getPeersHandler)
	}

	log.Println("VPN Control Plane starting on :8080")
	r.Run(":8080")
}

func getPeersHandler(c *gin.Context) {
	nodeID := c.Param("id")
	var peers []models.Peer
	if err := database.Where("node_id = ? AND active = ?", nodeID, true).Find(&peers).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "could not fetch peers"})
		return
	}

	c.JSON(http.StatusOK, peers)
}

func registerNodeHandler(c *gin.Context) {
	var input models.Node
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	input.LastSeen = time.Now()
	input.Status = "online"

	if err := database.Create(&input).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "could not register node"})
		return
	}

	c.JSON(http.StatusOK, input)
}

func heartbeatNodeHandler(c *gin.Context) {
	var input struct {
		NodeID uint `json:"node_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if err := database.Model(&models.Node{}).Where("id = ?", input.NodeID).Updates(map[string]interface{}{
		"last_seen": time.Now(),
		"status":    "online",
	}).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "could not update heartbeat"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "captured"})
}

type AuthInput struct {
	Email    string `json:"email" binding:"required"`
	Password string `json:"password" binding:"required"`
}

func registerHandler(c *gin.Context) {
	var input AuthInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	hashedPassword, err := auth.HashPassword(input.Password)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "could not hash password"})
		return
	}

	user := models.User{
		Email:    input.Email,
		Password: hashedPassword,
	}

	if err := database.Create(&user).Error; err != nil {
		c.JSON(http.StatusConflict, gin.H{"error": "user already exists or database error"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"message": "user created successfully"})
}

func loginHandler(c *gin.Context) {
	var input AuthInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var user models.User
	if err := database.Where("email = ?", input.Email).First(&user).Error; err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid credentials"})
		return
	}

	if !auth.CheckPasswordHash(input.Password, user.Password) {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid credentials"})
		return
	}

	token, err := auth.GenerateToken(user.ID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "could not generate token"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"token": token})
}
