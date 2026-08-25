# Changelog

## 1.0.0

- Initial release.
- Reverse-engineered XiongMai mobile-port (10510) client for CTV / XiongMai
  video doorbells (MobileEyeDoor+ / uCareHome), confirmed on CTV-M4101AHD.
- Bundled go2rtc republishes each camera channel as RTSP/WebRTC.
- Per-camera configuration via `cameras` option; device secret supplied as
  `login_hex`.
- `tools/extract_login.py` helper to recover the login frame from a capture.
