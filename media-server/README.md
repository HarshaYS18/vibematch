# Vibe Match Media Server

WebRTC MVP media server for internal testing.

## Goal

This service will run beside the FastAPI backend during local laptop-as-VPS testing.

## Local ports

- FastAPI backend: `8000`
- Media server HTTP/WebSocket: `9000`

## MVP flow

1. Start FastAPI backend on `0.0.0.0:8000`.
2. Start this media server on `0.0.0.0:9000`.
3. Point Flutter to your laptop Wi-Fi IP.
4. Join a room from two devices.
5. Put one user on a seat and publish mic audio.
6. Let the second user consume/listen.

## Required next test

Do not test every app feature at once. First test login and backend health, then room join, then WebSocket, then WebRTC audio.
