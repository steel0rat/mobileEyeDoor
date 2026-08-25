# Changelog

## 1.0.11

- Fix 1.0.10 breaking the door-panel channels. XiongMai frames video
  differently per channel: the yard camera glues its media header onto a NAL
  tail, but the panels send whole wrapper NALs (type 20). The 1.0.10 split on
  `02 00 00 00` only worked for the yard and starved the others. Now the client
  splits on H.264 start codes, trims any glued XiongMai header off each NAL, and
  keeps only real H.264 types — clean video on all four channels (verified 2.9-
  3.4 fps each).

## 1.0.10

- Fix the real cause of the periodic multi-second freezes: the client demuxed
  the XiongMai stream by splitting on H.264 start codes alone, which glued
  stray 16-byte media-packet header bytes onto frames. ffmpeg then hit garbage
  PPS ids ("pps_id out of range") and stalled 15-30s until the next clean
  keyframe. Now the client splits on the XiongMai media separator
  (`02 00 00 00`, impossible inside an H.264 RBSP) and emits clean H.264 —
  steady playback.

## 1.0.9

- Fix the jerky/freezing playback for real. The doorbell streams ~3 fps
  (measured) with no timestamps; ffmpeg was labeling it 25 fps, so players
  starved and stalled. Add `-use_wallclock_as_timestamps` so each frame is
  stamped by real arrival time — go2rtc/WebRTC now pace correctly and play
  smoothly. (It looked broken in 1.0.6-1.0.8 only because the doorbell was tied
  up by the earlier retry loop; on a free connection wall-clock copy works.)

## 1.0.8

- Revert the 1.0.6/1.0.7 re-encode: ffmpeg+libx264 on the doorbell's raw,
  low-fps pipe would not emit output within go2rtc's producer timeout (i/o
  timeout, no stream). Back to `-c:v copy`, which starts reliably.
- Drop the fixed `-r 25`: the doorbell runs ~5 fps variable, so 25 fps labels
  gave players bogus timings (a cause of the jerky/freezing playback). Without
  it go2rtc timestamps packets on arrival — smoother.

## 1.0.7

- Fix 1.0.6 not starting: `force_key_frames expr:gte(t,n_forced)` contains
  parentheses, which broke `bash -c` when go2rtc launched the pipeline (syntax
  error, no producer). Replaced with `-r 15 -g 15` — constant 15 fps and a
  keyframe every second, no shell metacharacters. CFR also smooths the
  doorbell's jittery frame rate for WebRTC.

## 1.0.6

- Fix the stream freezing for 15-30s during playback. The doorbell sends a low,
  variable frame rate with irregular keyframes (every 3-7s). The old `-c:v copy`
  with a fixed `-r 25` fed players bogus timestamps, and on any packet loss they
  stalled until the next keyframe. Now ffmpeg timestamps by wall-clock
  (`-use_wallclock_as_timestamps`) and re-encodes with a keyframe forced every
  second (`-force_key_frames`), so WebRTC/HLS recover within ~1s. The re-encode
  is negligible (low-fps 640x480, libx264 ultrafast).

## 1.0.5

- Enable real WebRTC (sub-second latency) instead of the MSE fallback. WebRTC
  needs a reachable ICE candidate, but go2rtc in the add-on only sees the
  container IP. New `webrtc_ip` option: set it to your HA host IP and the
  add-on advertises `<ip>:8555` (port now mapped to the host). Leave it empty
  and players use MSE as before.

## 1.0.4

- Preload every stream at startup (`preload:` section) so go2rtc keeps each
  doorbell channel connected instead of reconnecting on demand. Without it the
  first snapshot after an idle period still hit the ~5s cold-start reconnect,
  which stacked with Home Assistant's 10s snapshot timeout. Streams now stay
  warm and snapshots/previews return in ~1-2s.
- Note: this holds one TCP connection per camera to the doorbell at all times.
  XiongMai units allow only a few connections, so a phone app opening a 5th may
  be refused while the add-on runs.

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
