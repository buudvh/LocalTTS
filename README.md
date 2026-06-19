# LocalTTS iPhone Server

LocalTTS is an iOS SwiftUI app that exposes a localhost Vietnamese TTS API on
the iPhone. It mirrors the public voice/model catalog used by NGHI-TTS and
caches Piper ONNX model files inside the app sandbox.

## Current implementation

- Runs a local HTTP server on `127.0.0.1:17771`.
- Fetches Vietnamese voice names from `https://nghitts.app/api/piper/vi/models`.
- Caches the voice list locally.
- Prefetches `{voice}.onnx` and `{voice}.onnx.json` from NGHI-TTS.
- Defines the native Piper engine boundary for ONNX Runtime/eSpeak integration.

The API and cache layers are implemented. The final synthesis engine currently
returns `501 engine_unavailable` until ONNX Runtime Mobile and an eSpeak
phonemizer binding are linked in Xcode.

## API

```http
GET /health
GET /v1/voices
POST /v1/models/prefetch
POST /v1/tts
```

`POST /v1/models/prefetch`

```json
{
  "voices": ["Ngọc Huyền (mới)"]
}
```

`POST /v1/tts`

```json
{
  "text": "Xin chào, đây là thử giọng tiếng Việt.",
  "voice": "Ngọc Huyền (mới)",
  "speed": 1.0
}
```

## Open in Xcode

Open `LocalTTS.xcodeproj` on macOS, select a personal development team, then run
the `LocalTTS` target on an iPhone. Keep the app in the foreground while another
app calls `http://127.0.0.1:17771`.

## GitHub Actions IPA builds

The workflow at `.github/workflows/build-ipa.yml` builds an unsigned IPA artifact
on every push to `main` and through manual `workflow_dispatch`.

The unsigned IPA is useful as a CI artifact, but it is not enough for normal
iPhone installation. To produce a signed IPA, add these repository secrets:

- `BUILD_CERTIFICATE_BASE64`: base64-encoded `.p12` signing certificate.
- `P12_PASSWORD`: password for the `.p12`.
- `BUILD_PROVISION_PROFILE_BASE64`: base64-encoded `.mobileprovision`.
- `KEYCHAIN_PASSWORD`: temporary CI keychain password.
- `EXPORT_OPTIONS_PLIST`: base64-encoded `ExportOptions.plist`.

When all signing secrets are present, the `signed-ipa` job exports and uploads a
signed IPA artifact.

## Native Piper work remaining

To make `/v1/tts` produce real NGHI-TTS audio, link:

- ONNX Runtime Mobile or ONNX Runtime iOS.
- A Vietnamese eSpeak phonemizer compatible with Piper config files.
- A Swift wrapper that implements `PiperEngine`.

The integration point is `LocalTTS/Services/PiperTTSService.swift`.
