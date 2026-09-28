import assert from 'node:assert/strict';
import { test } from 'node:test';
import { RoomManager, canonicalPeerId } from '../src/mediasoup/roomManager.js';
import { config } from '../src/config.js';
import type { WorkerManager } from '../src/mediasoup/workerManager.js';
import type { VerifiedMediaUser } from '../src/types/mediaTypes.js';

function fixture() {
  let creates = 0;
  let closes = 0;
  const manager = new RoomManager({
    async createRouter() {
      creates++;
      await new Promise((resolve) => setImmediate(resolve));
      return { rtpCapabilities: {}, close() { closes++; } };
    },
  } as unknown as WorkerManager);
  return { manager, creates: () => creates, closes: () => closes };
}

test('simultaneous joins create exactly one router per room', async () => {
  const f = fixture();
  const rooms = await Promise.all(Array.from({ length: 20 }, () => f.manager.getOrCreateRoom('room')));
  assert.equal(f.creates(), 1);
  assert.ok(rooms.every((room) => room === rooms[0]));
});

test('in-flight router creation counts toward room capacity', async () => {
  const before = config.registry.maxRooms;
  config.registry.maxRooms = 1;
  try {
    const f = fixture();
    const first = f.manager.getOrCreateRoom('one');
    await assert.rejects(f.manager.getOrCreateRoom('two'), /capacity/);
    await first;
  } finally { config.registry.maxRooms = before; }
});

test('last peer departure closes router and all media resources', async () => {
  const f = fixture();
  const room = await f.manager.getOrCreateRoom('room');
  const peer = f.manager.ensurePeer({ room, socketId: 'socket', bearerToken: 'token', user: { user_id: 1 } as VerifiedMediaUser });
  const closed: string[] = [];
  peer.transports.set('transport', { close: () => closed.push('transport') } as never);
  peer.producers.set('producer', { close: () => closed.push('producer') } as never);
  peer.consumers.set('consumer', { close: () => closed.push('consumer') } as never);
  f.manager.closePeer('socket');
  assert.deepEqual(closed, ['consumer', 'producer', 'transport']);
  assert.equal(f.closes(), 1);
  assert.deepEqual(f.manager.getStats(), {
    roomCount: 0,
    peerCount: 0,
    hotRoomCount: 0,
    maxRoomPeers: 0,
    roomIds: [],
  });
});


test('canonical media peer ids are stable and server-derived', async () => {
  assert.equal(canonicalPeerId('VM354092', 6922022), 'VM354092_user_6922022');

  const f = fixture();
  const room = await f.manager.getOrCreateRoom('VM354092');
  const peer = f.manager.ensurePeer({
    room,
    socketId: 'transient-socket-id',
    bearerToken: 'token',
    user: {
      user_id: 1,
      public_user_id: 6922022,
      roles: ['user'],
      primary_role: 'user',
      is_active: true,
      is_banned: false,
    } as VerifiedMediaUser,
  });

  assert.equal(peer.socketId, 'transient-socket-id');
  assert.equal(peer.peerId, 'VM354092_user_6922022');
});
