# Cardinyoli
Cardinyoli is a card game implementation designed for multiplayer gameplay.

## Project Features
This game features:
* Multiplayer support with lobby identification
* Real-time updates
* Material Design
* Persistent storage
* Rules page
* Localization (english and catalan support)

## Project Architecture
It is build using Flutter and uses Google Firebase for real-time multiplayer functionality.

## Building with Docker
For local development, you can use Docker Compose if a `docker-compose.yml` is provided, or run multiple containers manually to simulate networked gameplay.

To run it as a web-server (for testing):
```bash
docker compose up web
```

To build the android app:
```bash
docker compose up apk
```
