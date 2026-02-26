package main

import (
	"fmt"
	"strings"
	"vpn-provider/internal/auth"
	"vpn-provider/internal/models"

	"net/http"

	"github.com/gin-gonic/gin"
)

func authMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization header required"})
			c.Abort()
			return
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if !(len(parts) == 2 && parts[0] == "Bearer") {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization header format must be Bearer {token}"})
			c.Abort()
			return
		}

		claims, err := auth.ValidateToken(parts[1])
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid or expired token"})
			c.Abort()
			return
		}

		// Store user info in context
		c.Set("userID", claims.UserID)
		c.Next()
	}
}

func connectHandler(c *gin.Context) {
	userID := c.MustGet("userID").(uint)

	var input struct {
		PublicKey string `json:"public_key" binding:"required"`
		NodeID    uint   `json:"node_id"` // Optional: user could pick a node
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// 1. Find a Node (Simplistic: pick first online node)
	var node models.Node
	query := database.Where("status = ?", "online")
	if input.NodeID != 0 {
		query = query.Where("id = ?", input.NodeID)
	}

	if err := query.First(&node).Error; err != nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "no VPN nodes available"})
		return
	}

	// 2. IP Allocation (Simplified POC: 10.8.0.2 to 10.8.0.254)
	// In a real system, you'd track used IPs in the DB or use a subnet manager
	var count int64
	database.Model(&models.Peer{}).Where("node_id = ?", node.ID).Count(&count)
	internalIP := fmt.Sprintf("10.8.0.%d", 2+count) // Naive sequential IP allocation

	// 3. Create/Update Peer
	peer := models.Peer{
		UserID:     userID,
		NodeID:     node.ID,
		InternalIP: internalIP,
		PublicKey:  input.PublicKey,
		Active:     true,
	}

	if err := database.Create(&peer).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to provision peer"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"node_public_ip":  node.PublicIP,
		"node_public_key": node.PublicKey,
		"node_port":       node.ListenPort,
		"internal_ip":     internalIP,
		"dns":             "1.1.1.1", // POC default
	})
}

func downloadConfigHandler(c *gin.Context) {
	userID := c.MustGet("userID").(uint)
	peerID := c.Param("peerID")

	var peer models.Peer
	if err := database.Preload("Node").Where("id = ? AND user_id = ?", peerID, userID).First(&peer).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "peer configuration not found"})
		return
	}

	// In a real app, the client has their Private Key.
	// For this POC dashboard "Download Config" to work, the user would provide their Private Key
	// or we'd have to store it (unsafe).
	// We'll return a template where the user just needs to paste their Private Key.
	config := fmt.Sprintf(`[Interface]
PrivateKey = <PASTE_YOUR_PRIVATE_KEY_HERE>
Address = %s/32
DNS = 1.1.1.1

[Peer]
PublicKey = %s
Endpoint = %s:%d
AllowedIPs = 0.0.0.0/0
`, peer.InternalIP, peer.Node.PublicKey, peer.Node.PublicIP, peer.Node.ListenPort)

	c.Header("Content-Disposition", "attachment; filename=vpn.conf")
	c.Data(http.StatusOK, "application/x-wireguard-config", []byte(config))
}
