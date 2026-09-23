package gateway

import (
	"encoding/json"
	"hash/fnv"
	"strconv"
	"sync"
	"sync/atomic"
	"time"

	"github.com/gorilla/websocket"
)

const (
	defaultHubShardCount = 32
	defaultDedupeEntries = 65536
	defaultDedupeTTL     = 5 * time.Minute
)

type deliveryPriority uint8

const (
	deliveryBestEffort deliveryPriority = iota
	deliveryNormal
	deliveryCritical
)

type enqueueResult uint8

const (
	enqueueAccepted enqueueResult = iota
	enqueueDropped
	enqueueOverflow
)

type outboundQueue struct {
	mu         sync.Mutex
	capacity   int
	critical   [][]byte
	normal     [][]byte
	bestEffort [][]byte
	notify     chan struct{}
}

func newOutboundQueue(capacity int) *outboundQueue {
	if capacity < 4 {
		capacity = 4
	}
	return &outboundQueue{
		capacity: capacity,
		notify:   make(chan struct{}, 1),
	}
}

func (q *outboundQueue) sizeLocked() int {
	return len(q.critical) + len(q.normal) + len(q.bestEffort)
}

func (q *outboundQueue) signal() {
	select {
	case q.notify <- struct{}{}:
	default:
	}
}

func (q *outboundQueue) push(payload []byte, priority deliveryPriority) (enqueueResult, bool) {
	q.mu.Lock()
	defer q.mu.Unlock()

	evicted := false
	if q.sizeLocked() >= q.capacity {
		switch priority {
		case deliveryBestEffort:
			return enqueueDropped, false
		case deliveryNormal:
			if len(q.bestEffort) == 0 {
				return enqueueOverflow, false
			}
			q.bestEffort = q.bestEffort[1:]
			evicted = true
		case deliveryCritical:
			switch {
			case len(q.bestEffort) > 0:
				q.bestEffort = q.bestEffort[1:]
				evicted = true
			case len(q.normal) > 0:
				q.normal = q.normal[1:]
				evicted = true
			default:
				return enqueueOverflow, false
			}
		}
	}

	switch priority {
	case deliveryCritical:
		q.critical = append(q.critical, payload)
	case deliveryBestEffort:
		q.bestEffort = append(q.bestEffort, payload)
	default:
		q.normal = append(q.normal, payload)
	}
	q.signal()
	return enqueueAccepted, evicted
}

func (q *outboundQueue) pop() ([]byte, bool) {
	q.mu.Lock()
	defer q.mu.Unlock()

	if len(q.critical) > 0 {
		payload := q.critical[0]
		q.critical = q.critical[1:]
		return payload, true
	}
	if len(q.normal) > 0 {
		payload := q.normal[0]
		q.normal = q.normal[1:]
		return payload, true
	}
	if len(q.bestEffort) > 0 {
		payload := q.bestEffort[0]
		q.bestEffort = q.bestEffort[1:]
		return payload, true
	}
	return nil, false
}

func (q *outboundQueue) len() int {
	q.mu.Lock()
	defer q.mu.Unlock()
	return q.sizeLocked()
}

type Client struct {
	ID      string
	UserID  int64
	IsStaff bool
	Token   string
	Conn    *websocket.Conn
	queue   *outboundQueue
	done    chan struct{}
	rooms   map[string]struct{}
	once    sync.Once
}

func newClient(
	id string,
	userID int64,
	isStaff bool,
	token string,
	conn *websocket.Conn,
	queueSize int,
) *Client {
	return &Client{
		ID: id, UserID: userID, IsStaff: isStaff, Token: token, Conn: conn,
		queue: newOutboundQueue(queueSize), done: make(chan struct{}),
		rooms: make(map[string]struct{}),
	}
}

type Stats struct {
	Connections        atomic.Int64
	Accepted           atomic.Uint64
	AuthDenied         atomic.Uint64
	SlowClosed         atomic.Uint64
	Events             atomic.Uint64
	InvalidEvents      atomic.Uint64
	DuplicateEvents    atomic.Uint64
	CapacityDenied     atomic.Uint64
	BestEffortDropped  atomic.Uint64
	LowerPriorityEvict atomic.Uint64
}

type routeShard struct {
	mu     sync.RWMutex
	byUser map[int64]map[*Client]struct{}
	byRoom map[string]map[*Client]struct{}
}

type dedupeRecord struct {
	id        string
	expiresAt time.Time
}

type boundedDedupe struct {
	mu    sync.Mutex
	seen  map[string]time.Time
	order []dedupeRecord
	max   int
	ttl   time.Duration
}

func newBoundedDedupe(max int, ttl time.Duration) *boundedDedupe {
	if max < 1 {
		max = 1
	}
	if ttl <= 0 {
		ttl = time.Minute
	}
	return &boundedDedupe{
		seen: make(map[string]time.Time),
		max:  max,
		ttl:  ttl,
	}
}

func (d *boundedDedupe) accept(id string, now time.Time) bool {
	d.mu.Lock()
	defer d.mu.Unlock()

	for len(d.order) > 0 {
		head := d.order[0]
		if head.expiresAt.After(now) && len(d.seen) < d.max {
			break
		}
		d.order = d.order[1:]
		if current, ok := d.seen[head.id]; ok && current.Equal(head.expiresAt) {
			delete(d.seen, head.id)
		}
	}
	if expiresAt, exists := d.seen[id]; exists && expiresAt.After(now) {
		return false
	}
	for len(d.seen) >= d.max && len(d.order) > 0 {
		head := d.order[0]
		d.order = d.order[1:]
		if current, ok := d.seen[head.id]; ok && current.Equal(head.expiresAt) {
			delete(d.seen, head.id)
		}
	}
	expiresAt := now.Add(d.ttl)
	d.seen[id] = expiresAt
	d.order = append(d.order, dedupeRecord{id: id, expiresAt: expiresAt})
	return true
}

func (d *boundedDedupe) size() int {
	d.mu.Lock()
	defer d.mu.Unlock()
	return len(d.seen)
}

type Hub struct {
	mu       sync.RWMutex
	clients  map[*Client]struct{}
	staff    map[*Client]struct{}
	shards   []routeShard
	draining bool
	dedupe   *boundedDedupe
	stats    Stats
}

func NewHub() *Hub {
	return newHubWithShards(defaultHubShardCount)
}

func newHubWithShards(count int) *Hub {
	if count < 1 {
		count = 1
	}
	shards := make([]routeShard, count)
	for index := range shards {
		shards[index] = routeShard{
			byUser: make(map[int64]map[*Client]struct{}),
			byRoom: make(map[string]map[*Client]struct{}),
		}
	}
	return &Hub{
		clients: make(map[*Client]struct{}),
		staff:   make(map[*Client]struct{}),
		shards:  shards,
		dedupe:  newBoundedDedupe(defaultDedupeEntries, defaultDedupeTTL),
	}
}

func (h *Hub) userShard(userID int64) *routeShard {
	index := int(userID % int64(len(h.shards)))
	if index < 0 {
		index = -index
	}
	return &h.shards[index]
}

func (h *Hub) roomShard(roomID string) *routeShard {
	hasher := fnv.New32a()
	_, _ = hasher.Write([]byte(roomID))
	return &h.shards[int(hasher.Sum32()%uint32(len(h.shards)))]
}

func (h *Hub) Add(c *Client, maxConnections int64, maxConnectionsPerUser int) bool {
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.draining || int64(len(h.clients)) >= maxConnections {
		h.stats.CapacityDenied.Add(1)
		return false
	}

	userShard := h.userShard(c.UserID)
	userShard.mu.Lock()
	defer userShard.mu.Unlock()
	if maxConnectionsPerUser > 0 && len(userShard.byUser[c.UserID]) >= maxConnectionsPerUser {
		h.stats.CapacityDenied.Add(1)
		return false
	}

	h.clients[c] = struct{}{}
	if c.IsStaff {
		h.staff[c] = struct{}{}
	}
	if userShard.byUser[c.UserID] == nil {
		userShard.byUser[c.UserID] = make(map[*Client]struct{})
	}
	userShard.byUser[c.UserID][c] = struct{}{}
	h.stats.Connections.Add(1)
	h.stats.Accepted.Add(1)
	return true
}

func (h *Hub) Subscribe(c *Client, roomID string) bool {
	h.mu.Lock()
	if _, active := h.clients[c]; !active || h.draining {
		h.mu.Unlock()
		return false
	}
	if _, subscribed := c.rooms[roomID]; subscribed {
		h.mu.Unlock()
		return true
	}
	if len(c.rooms) >= 8 {
		h.mu.Unlock()
		return false
	}
	c.rooms[roomID] = struct{}{}
	h.mu.Unlock()

	shard := h.roomShard(roomID)
	shard.mu.Lock()
	defer shard.mu.Unlock()
	if shard.byRoom[roomID] == nil {
		shard.byRoom[roomID] = make(map[*Client]struct{})
	}
	shard.byRoom[roomID][c] = struct{}{}
	return true
}

func (h *Hub) Unsubscribe(c *Client, roomID string) {
	h.mu.Lock()
	delete(c.rooms, roomID)
	h.mu.Unlock()

	shard := h.roomShard(roomID)
	shard.mu.Lock()
	defer shard.mu.Unlock()
	delete(shard.byRoom[roomID], c)
	if len(shard.byRoom[roomID]) == 0 {
		delete(shard.byRoom, roomID)
	}
}

func (h *Hub) Remove(c *Client) {
	h.mu.Lock()
	if _, active := h.clients[c]; !active {
		h.mu.Unlock()
		return
	}
	delete(h.clients, c)
	delete(h.staff, c)
	rooms := make([]string, 0, len(c.rooms))
	for roomID := range c.rooms {
		rooms = append(rooms, roomID)
	}
	c.rooms = make(map[string]struct{})
	h.mu.Unlock()

	userShard := h.userShard(c.UserID)
	userShard.mu.Lock()
	delete(userShard.byUser[c.UserID], c)
	if len(userShard.byUser[c.UserID]) == 0 {
		delete(userShard.byUser, c.UserID)
	}
	userShard.mu.Unlock()

	for _, roomID := range rooms {
		shard := h.roomShard(roomID)
		shard.mu.Lock()
		delete(shard.byRoom[roomID], c)
		if len(shard.byRoom[roomID]) == 0 {
			delete(shard.byRoom, roomID)
		}
		shard.mu.Unlock()
	}

	h.stats.Connections.Add(-1)
	c.once.Do(func() {
		close(c.done)
		if c.Conn != nil {
			_ = c.Conn.Close()
		}
	})
}

func priorityFor(event Event) deliveryPriority {
	switch event.DeliveryPriority() {
	case PriorityCritical:
		return deliveryCritical
	case PriorityBestEffort:
		return deliveryBestEffort
	default:
		return deliveryNormal
	}
}

func (h *Hub) Enqueue(c *Client, payload []byte) bool {
	result, evicted := c.queue.push(payload, deliveryNormal)
	if evicted {
		h.stats.LowerPriorityEvict.Add(1)
	}
	return result == enqueueAccepted
}

func (h *Hub) EnqueueCritical(c *Client, payload []byte) bool {
	result, evicted := c.queue.push(payload, deliveryCritical)
	if evicted {
		h.stats.LowerPriorityEvict.Add(1)
	}
	return result == enqueueAccepted
}

func (h *Hub) EnqueueBestEffort(c *Client, payload []byte) bool {
	result, _ := c.queue.push(payload, deliveryBestEffort)
	if result == enqueueDropped {
		h.stats.BestEffortDropped.Add(1)
		return true
	}
	return result == enqueueAccepted
}

func (h *Hub) recipientsForUser(userID int64) map[*Client]struct{} {
	shard := h.userShard(userID)
	shard.mu.RLock()
	defer shard.mu.RUnlock()
	out := make(map[*Client]struct{}, len(shard.byUser[userID]))
	for client := range shard.byUser[userID] {
		out[client] = struct{}{}
	}
	return out
}

func (h *Hub) recipientsForRoom(roomID string) map[*Client]struct{} {
	shard := h.roomShard(roomID)
	shard.mu.RLock()
	defer shard.mu.RUnlock()
	out := make(map[*Client]struct{}, len(shard.byRoom[roomID]))
	for client := range shard.byRoom[roomID] {
		out[client] = struct{}{}
	}
	return out
}

func (h *Hub) recipients(event Event) map[*Client]struct{} {
	switch event.Scope {
	case "room":
		return h.recipientsForRoom(event.RoomPublicID)
	case "user":
		return h.recipientsForUser(event.UserID)
	case "users":
		out := make(map[*Client]struct{})
		for _, userID := range event.UserIDs {
			for client := range h.recipientsForUser(userID) {
				out[client] = struct{}{}
			}
		}
		return out
	case "staff":
		h.mu.RLock()
		defer h.mu.RUnlock()
		out := make(map[*Client]struct{}, len(h.staff))
		for client := range h.staff {
			out[client] = struct{}{}
		}
		return out
	case "all":
		h.mu.RLock()
		defer h.mu.RUnlock()
		out := make(map[*Client]struct{}, len(h.clients))
		for client := range h.clients {
			out[client] = struct{}{}
		}
		return out
	default:
		return nil
	}
}

func (h *Hub) Publish(event Event, raw []byte) {
	if err := event.Validate(); err != nil {
		h.stats.InvalidEvents.Add(1)
		return
	}
	if !h.dedupe.accept(event.EventID, time.Now()) {
		h.stats.DuplicateEvents.Add(1)
		return
	}
	h.stats.Events.Add(1)

	priority := priorityFor(event)
	for client := range h.recipients(event) {
		result, evicted := client.queue.push(raw, priority)
		if evicted {
			h.stats.LowerPriorityEvict.Add(1)
		}
		switch result {
		case enqueueDropped:
			h.stats.BestEffortDropped.Add(1)
		case enqueueOverflow:
			h.stats.SlowClosed.Add(1)
			h.Remove(client)
		}
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
		if !h.EnqueueCritical(c, message) {
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
		"funkey_realtime_events_invalid_total " + strconv.FormatUint(h.stats.InvalidEvents.Load(), 10) + "\n" +
		"funkey_realtime_events_duplicate_total " + strconv.FormatUint(h.stats.DuplicateEvents.Load(), 10) + "\n" +
		"funkey_realtime_capacity_denied_total " + strconv.FormatUint(h.stats.CapacityDenied.Load(), 10) + "\n" +
		"funkey_realtime_best_effort_dropped_total " + strconv.FormatUint(h.stats.BestEffortDropped.Load(), 10) + "\n" +
		"funkey_realtime_lower_priority_evicted_total " + strconv.FormatUint(h.stats.LowerPriorityEvict.Load(), 10) + "\n" +
		"funkey_realtime_dedupe_entries " + strconv.Itoa(h.dedupe.size()) + "\n"
}
