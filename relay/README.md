# Enjoy relay

Node 22 service between the HarmonyOS app and the Cursor SDK. Text requests use model `auto`, so they bill the API key's Auto usage pool. The key stays on the server. Cache and usage are stored with Node's built-in `node:sqlite` (the `better-sqlite3` native addon does not build on current Node).

## Run

```bash
cp .env.example .env
# set CURSOR_API_KEY and RELAY_TOKEN
npm install
npm run build
npm start
```

Or `docker compose up --build`. The phone then uses `http://<host>:8787` and the same `RELAY_TOKEN`.

`GET /health` is public. Every `/v1/*` route requires `Authorization: Bearer <RELAY_TOKEN>`.

## Routes

| Method | Path | Body |
| --- | --- | --- |
| POST | `/v1/lookup` | `{ word, context? }` JSON dictionary entry. Cached. |
| POST | `/v1/translate` | `{ text }` translation. Cached. |
| POST | `/v1/analyze` | `{ text }` grammar notes in Chinese. |
| POST | `/v1/refine` | `{ text, context? }` more natural wording. |
| POST | `/v1/suggest` | `{ context }` at least five replies. |
| POST | `/v1/chat` | `{ role, messages, message }` SSE (`delta`, `done`, `error`). |
| GET | `/v1/usage` | Token totals recorded from Cursor run usage. |
| POST | `/v1/score` | `{ reference, hypothesis }` word-level score. No model call. |
| POST | `/v1/transcribe` | multipart `audio`. Needs whisper.cpp. |
| POST | `/v1/assess` | multipart `audio` + `reference`. Transcribe, then score. |

Lookup and translate accept optional `learningLanguage` (default `en-US`) and `nativeLanguage` (default `zh-CN`).

A startup failure from the SDK is `error: "startup"` (the run never began). `error: "run"` means the run started and failed. Timeouts are HTTP 504. Concurrency defaults to 2, and each Cursor call times out after 60 seconds.

## Transcription

HarmonyOS on-device speech recognition does not currently transcribe English. Install whisper.cpp beside the relay:

```bash
bash scripts/install-whisper.sh
```

Put the printed `WHISPER_BIN` and `WHISPER_MODEL` paths in `.env`. `ffmpeg` must be on `PATH` (the Docker image already includes it). The whisper binary inside the image is optional: mount a built `whisper.cpp` directory, as `docker-compose.yml` does.

This package is part of a GPL-3.0-only project.
