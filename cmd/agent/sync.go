package main

import (
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"vpn-provider/internal/models"

	"golang.zx2c4.com/wireguard/wgctrl"
	"golang.zx2c4.com/wireguard/wgctrl/wgtypes"
)

func syncPeers(nodeID uint) error {
	// 1. Fetch peers from backend
	resp, err := http.Get(fmt.Sprintf("%s/nodes/%d/peers", backendURL, nodeID))
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	var peers []models.Peer
	if err := json.NewDecoder(resp.Body).Decode(&peers); err != nil {
		return err
	}

	// 2. Configure WireGuard
	client, err := wgctrl.New()
	if err != nil {
		return err
	}
	defer client.Close()

	var wgPeers []wgtypes.PeerConfig
	for _, p := range peers {
		publicKey, err := wgtypes.ParseKey(p.PublicKey)
		if err != nil {
			continue
		}

		_, ipNet, err := net.ParseCIDR(p.InternalIP + "/32")
		if err != nil {
			continue
		}

		wgPeers = append(wgPeers, wgtypes.PeerConfig{
			PublicKey:         publicKey,
			AllowedIPs:        []net.IPNet{*ipNet},
			ReplaceAllowedIPs: true,
		})
	}

	err = client.ConfigureDevice("wg0", wgtypes.Config{
		Peers:        wgPeers,
		ReplacePeers: true,
	})

	if err != nil {
		return fmt.Errorf("failed to configure wg0: %v (make sure wg0 interface exists)", err)
	}

	fmt.Printf("Synced %d peers to wg0\n", len(wgPeers))
	return nil
}
