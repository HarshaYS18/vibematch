import asyncio
import json
import sys
from urllib.parse import quote

try:
    import websockets
except ImportError as exc:
    raise SystemExit(
        "Missing dependency: websockets. Install with: python -m pip install websockets"
    ) from exc


async def main() -> None:
    room_id = sys.argv[1] if len(sys.argv) > 1 else "VM123456"
    user_id = sys.argv[2] if len(sys.argv) > 2 else "6418000001"
    display_name = sys.argv[3] if len(sys.argv) > 3 else "Harsha"

    url = (
        f"ws://127.0.0.1:8000/ws/rooms/{quote(room_id)}"
        f"?user_id={quote(user_id)}&display_name={quote(display_name)}"
    )

    print(f"Connecting to {url}")
    async with websockets.connect(url) as websocket:
        print("Connected. Incoming initial events:")
        for _ in range(2):
            print(await websocket.recv())

        message = {
            "type": "room.message.send",
            "room_id": room_id,
            "user_id": user_id,
            "request_id": "local-test-1",
            "payload": {"text": "Hello from local WebSocket test"},
        }
        await websocket.send(json.dumps(message))
        print("Sent room.message.send")
        print(await websocket.recv())

        ping = {
            "type": "ping",
            "room_id": room_id,
            "request_id": "ping-1",
            "payload": {},
        }
        await websocket.send(json.dumps(ping))
        print("Sent ping")
        print(await websocket.recv())


if __name__ == "__main__":
    asyncio.run(main())
