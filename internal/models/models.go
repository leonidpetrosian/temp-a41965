package models

import (
	"time"
)

type User struct {
	ID        uint      `gorm:"primaryKey" json:"id"`
	Email     string    `gorm:"uniqueIndex;not null" json:"email"`
	Password  string    `gorm:"not null" json:"-"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

type Node struct {
	ID         uint      `gorm:"primaryKey" json:"id"`
	Name       string    `json:"name"`
	PublicIP   string    `gorm:"not null" json:"public_ip"`
	PublicKey  string    `gorm:"not null" json:"public_key"`
	ListenPort int       `gorm:"default:51820" json:"listen_port"`
	Region     string    `json:"region"`
	LastSeen   time.Time `json:"last_seen"`
	Status     string    `gorm:"default:'offline'" json:"status"` // online, offline, maintenance
}

type Peer struct {
	ID         uint      `gorm:"primaryKey" json:"id"`
	UserID     uint      `gorm:"not null" json:"user_id"`
	NodeID     uint      `gorm:"not null" json:"node_id"`
	Node       Node      `gorm:"foreignKey:NodeID" json:"node"`
	InternalIP string    `gorm:"uniqueIndex;not null" json:"internal_ip"`
	PublicKey  string    `gorm:"not null" json:"public_key"`
	Active     bool      `gorm:"default:true" json:"active"`
	CreatedAt  time.Time `json:"created_at"`
}
