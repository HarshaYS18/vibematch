package gateway

import (
	"encoding/json"
	"strconv"
	"sync"
	"sync/atomic"
	"time"

	"github.com/gorilla/websocket"
)

type Client struct {
	ID     string
	UserID int64
	Token  string
	Conn   *websocket.Conn
	send   chan []byte
	done   chan struct{}
	rooms  map[string]struct{}
	once   sync.Once
}

func newClient(id string, userID int64, token string, conn *websocket.Conn, queueSize int) *Client {
	return &Client{
		ID: id, UserID: userID, Token: token, Conn: conn,
		send: make(chan []byte, queueSize), done: make(chan struct{}),
		rooms: make(map[string]struct{}),
	}
}

type Stats struct {
	Connections   atomic.Int64
	Accepted      atomic.Uint64
	AuthDenied    atomic.Uint64
	SlowClosed    atomic.Uint64
	Events        atomic.Uint64
	InvalidEvents atomic.Uint64
}

type Hub struct {
	mu       sync.RWMutex
	clients  map[*Client]struct{}
	byUser   map[int64]map[*Client]struct{}
	byRoom   map[string]map[*Client]struct{}
	draining bool
	stats    Stats
}

func NewHub() *Hub {
	return &Hub{
		clients: make(map[*Client]struct{}),
		byUser:  make(map[int64]map[*Client]struct{}),
		byRoom:  make(map[string]map[*Client]struct{}),
	}
}

func (h *Hub) Add(c *Client, maxConnections int64) bool {
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.draining || int64(len(h.clients)) >= maxConnections {
		return false
	}
	h.clients[c] = struct{}{}
	if h.byUser[c.UserID] == nil {
		h.byUser[c.UserID] = make(map[*Client]struct{})
	}
	h.byUser[c.UserID][c] = struct{}{}
	h.stats.Connections.Add(1)
	h.stats.Accepted.Add(1)
	return true
}

func (h *Hub) Subscribe(c *Client, roomID string) bool {
	h.mu.Lock()
	defer h.mu.Unlock()
	if _, active := h.clients[c]; !active || h.draining {
		return false
	}
	if _, subscribed := c.rooms[roomID]; subscribed {
		return true
	}
	if len(c.rooms) >= 8 {
		return false
	}
	c.rooms[roomID] = struct{}{}
	if h.byRoom[roomID] == nil {
		h.byRoom[roomID] = make(map[*Client]struct{})
	}
	h.byRoom[roomID][c] = struct{}{}
	return true
}

func (h *Hub) Unsubscribe(c *Client, roomID string) {
	h.mu.Lock()
	defer h.mu.Unlock()
	delete(c.rooms, roomID)
	delete(h.byRoom[roomID], c)
	if len(h.byRoom[roomID]) == 0 {
		delete(h.byRoom, roomID)
	}
}

func (h *Hub) Remove(c *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if _, active := h.clients[c]; !active {
		return
	}
	delete(h.clients, c)
	delete(h.byUser[c.UserID], c)
	if len(h.byUser[c.UserID]) == 0 {
		delete(h.byUser, c.UserID)
	}
	for roomID := range c.rooms {
		delete(h.byRoom[roomID], c)
		if len(h.byRoom[roomID]) == 0 {
			delete(h.byRoom, roomID)
		}
	}
	h.stats.Connections.Add(-1)
	c.once.Do(func() {
		close(c.done)
		if c.Conn != nil {
			_ = c.Conn.Close()
		}
	})
}

func (h *Hub) Publish(event Event, raw []byte) {
	if err := event.Validate(); err != nil {
		h.stats.InvalidEvents.Add(1)
		return
	}
	h.stats.Events.Add(1)
	h.mu.RLock()
	var recipients map[*Client]struct{}
	if event.Scope == "room" {
		recipients = h.byRoom[event.RoomPublicID]
	} else {
		recipients = h.byUser[event.UserID]
	}
	clients := make([]*Client, 0, len(recipients))
	for c := range recipients {
		clients = append(clients, c)
	}
	h.mu.RUnlock()
	for _, c := range clients {
		if !h.Enqueue(c, raw) {
			h.stats.SlowClosed.Add(1)
			h.Remove(c)
		}
	}
}

func (h *Hub) Enqueue(c *Client, payload []byte) bool {
	select {
	case <-c.done:
		return true
	default:
	}
	select {
	case c.send <- payload:
		return true
	default:
		return false
	}
}

func (h *Hub) Drain(deadline time.Time) {
	h.mu.Lock()
	h.draining = true
	clients := make([]*Client, 0, len(h.clients))
	for c := range h.clients {
		clients = append(clients, c)
	}
	h.mu.Unlock()
	message, _ := json.Marshal(map[string]any{
		"type":               "server.draining",
		"reconnect_after_ms": 1000,
		"deadline":           deadline.UTC().Format(time.RFC3339),
	})
	for _, c := range clients {
		if !h.Enqueue(c, message) {
			h.Remove(c)
		}
	}
}

func (h *Hub) IsDraining() bool {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return h.draining
}

func (h *Hub) Clients() []*Client {
	h.mu.RLock()
	defer h.mu.RUnlock()
	clients := make([]*Client, 0, len(h.clients))
	for c := range h.clients {
		clients = append(clients, c)
	}
	return clients
}

func (h *Hub) Rooms(c *Client) []string {
	h.mu.RLock()
	defer h.mu.RUnlock()
	rooms := make([]string, 0, len(c.rooms))
	for roomID := range c.rooms {
		rooms = append(rooms, roomID)
	}
	return rooms
}

func (h *Hub) CloseAll() {
	for _, c := range h.Clients() {
		h.Remove(c)
	}
}

func (h *Hub) Metrics() string {
	return "funkey_realtime_connections " + strconv.FormatInt(h.stats.Connections.Load(), 10) + "\n" +
		"funkey_realtime_connections_accepted_total " + strconv.FormatUint(h.stats.Accepted.Load(), 10) + "\n" +
		"funkey_realtime_auth_denied_total " + strconv.FormatUint(h.stats.AuthDenied.Load(), 10) + "\n" +
		"funkey_realtime_slow_clients_closed_total " + strconv.FormatUint(h.stats.SlowClosed.Load(), 10) + "\n" +
		"funkey_realtime_events_received_total " + strconv.FormatUint(h.stats.Events.Load(), 10) + "\n" +
		"funkey_realtime_events_invalid_total " + strconv.FormatUint(h.stats.InvalidEvents.Load(), 10) + "\n"
}
