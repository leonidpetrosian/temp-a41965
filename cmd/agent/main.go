package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"
	"vpn-provider/internal/models"
	"vpn-provider/internal/wg"
)

const (
	backendURL = "http://localhost:8080" // In production, use environment variables
	nodeRegion = "US-East"
	publicIP   = "34.62.136.247" // Should be auto-detected or configured
)

func main() {
	fmt.Println("VPN Node Agent Starting...")

	keys, err := wg.GenerateKeyPair()
	if err != nil {
		log.Fatalf("Failed to generate WireGuard keys: %v", err)
	}

	node := models.Node{
		Name:      "Node-POC",
		PublicIP:  publicIP,
		PublicKey: keys.PublicKey,
		Region:    nodeRegion,
	}

	// Register with backend
	registeredNode, err := registerWithBackend(node)
	if err != nil {
		log.Fatalf("Failed to register with backend: %v", err)
	}

	fmt.Printf("Node registered with ID: %d\n", registeredNode.ID)

	// Heartbeat & Sync loop
	ticker := time.NewTicker(30 * time.Second)
	for range ticker.C {
		fmt.Println("Sending heartbeat...")
		if err := sendHeartbeat(registeredNode.ID); err != nil {
			log.Printf("Heartbeat failed: %v", err)
		}

		fmt.Println("Syncing peers...")
		if err := syncPeers(registeredNode.ID); err != nil {
			log.Printf("Peer sync failed: %v", err)
		}
	}
}

func registerWithBackend(node models.Node) (*models.Node, error) {
	jsonData, _ := json.Marshal(node)
	resp, err := http.Post(backendURL+"/nodes/register", "application/json", bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("backend returned status: %d", resp.StatusCode)
	}

	var result models.Node
	json.NewDecoder(resp.Body).Decode(&result)
	return &result, nil
}

func sendHeartbeat(nodeID uint) error {
	payload := map[string]uint{"node_id": nodeID}
	jsonData, _ := json.Marshal(payload)
	resp, err := http.Post(backendURL+"/nodes/heartbeat", "application/json", bytes.NewBuffer(jsonData))
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("backend returned status: %d", resp.StatusCode)
	}

	return nil
}
