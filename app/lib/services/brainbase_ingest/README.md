# Brainbase R2 ingest lane

This optional personal-use lane mirrors Omi BLE audio into 30-second WAV
chunks. Chunks are written to app support storage before upload, retried after
network failures or app restarts, and deleted only after the Worker confirms
them. Omi's existing WAL and WebSocket paths remain authoritative and do not
wait for this network lane.

Enable it at build time:

```bash
flutter run \
  --dart-define=BRAINBASE_INGEST_URL=https://brainbase-omi-ingest.unson.workers.dev \
  --dart-define=BRAINBASE_INGEST_TOKEN="$BRAINBASE_INGEST_TOKEN"
```

If either define is absent, the lane is a no-op. Do not commit the token. A
`dart-define` secret can be extracted from a distributed application binary,
so this authentication model is only suitable for the owner's private build.
Replace it with device registration and short-lived credentials before any
third-party distribution.
