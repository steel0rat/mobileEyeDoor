# Changelog

## 1.0.3

- Real fix for the slow first frame (HTTP 500 on snapshots): cap ffmpeg's input
  probe with `-probesize 32768 -analyzeduration 0`. The raw Annex-B stream has
  no timestamps and a low bitrate, so ffmpeg's default 5 MB probe kept
  analysing for ~28-40s before emitting a frame. With the cap, startup is ~2s.
- Revert the 1.0.2 re-encode: the doorbell already sends frequent keyframes, so
  `-c:v copy` is enough — no CPU cost, original quality. The 1.0.2 GOP theory
  was wrong; measured first-IDR latency on a fresh connection is 0.5s.

## 1.0.2

- Re-encode each stream with a 1s keyframe interval (`-g 25`) instead of
  `-c:v copy`. The doorbell emits an IDR only about once every ~28s, so
  snapshots and Home Assistant camera previews used to stall past their
  timeouts (HTTP 500). Keyframes now arrive every second and previews load
  immediately.

## 1.0.1

- Fix H.264 corruption ("grey mush", decode errors): NAL units that straddle
  TCP recv boundaries are now buffered across reads and only complete units are
  emitted. Live streams decode cleanly.

## 1.0.0

- Initial release.
- Reverse-engineered XiongMai mobile-port (10510) client for CTV / XiongMai
  video doorbells (MobileEyeDoor+ / uCareHome), confirmed on CTV-M4101AHD.
- Bundled go2rtc republishes each camera channel as RTSP/WebRTC.
- Per-camera configuration via `cameras` option; device secret supplied as
  `login_hex`.
- `tools/extract_login.py` helper to recover the login frame from a capture.
