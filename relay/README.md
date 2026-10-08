# Enjoy speech relay

Optional Node 22 service for English transcription and pronunciation scoring. The HarmonyOS app calls GLM or MiniMax directly for text. This process only receives audio.

## Run

```bash
cp .env.example .env
# set RELAY_TOKEN
npm install
npm run build
npm start
```

Or `docker compose up --build`. The phone then uses `http://<host>:8787` and the same `RELAY_TOKEN` in 「我的」→ 语音中转.

`GET /health` is public. Every `/v1/*` route requires `Authorization: Bearer <RELAY_TOKEN>`.

## Routes

| Method | Path | Body |
| --- | --- | --- |
| POST | `/v1/score` | `{ reference, hypothesis }` word-level score. No model call. |
| POST | `/v1/transcribe` | multipart `audio`. Needs whisper.cpp. |
| POST | `/v1/assess` | multipart `audio` + `reference`. Transcribe, then score. |

## Transcription

HarmonyOS on-device speech recognition does not currently transcribe English. Install whisper.cpp beside the relay:

```bash
bash scripts/install-whisper.sh
```

Put the printed `WHISPER_BIN` and `WHISPER_MODEL` paths in `.env`. `ffmpeg` must be on `PATH` (the Docker image already includes it). The whisper binary inside the image is optional: mount a built `whisper.cpp` directory, as `docker-compose.yml` does.

This package is part of a GPL-3.0-only project.
