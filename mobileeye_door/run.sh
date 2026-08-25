#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
set -e

HOST="$(bashio::config 'host')"
PORT="$(bashio::config 'port')"
LOGIN_HEX="$(bashio::config 'login_hex')"

if bashio::var.is_empty "${HOST}"; then
    bashio::exit.nok "Option 'host' is required (doorbell IP address)."
fi
if bashio::var.is_empty "${LOGIN_HEX}"; then
    bashio::exit.nok "Option 'login_hex' is required (see README: capture your login frame)."
fi

export DOORBELL_HOST="${HOST}"
export DOORBELL_PORT="${PORT}"
export LOGIN_HEX="${LOGIN_HEX}"

# WebRTC needs an ICE candidate the browser can actually reach. go2rtc inside
# the add-on only sees the container IP (172.30.x), which no browser can dial,
# so the user supplies the HA host IP via webrtc_ip and we advertise it on
# :8555 (the port mapped to the host). Without it WebRTC can't connect and
# players fall back to slower MSE.
WEBRTC_IP="$(bashio::config 'webrtc_ip')"
if bashio::var.has_value "${WEBRTC_IP}"; then
    WEBRTC_CANDIDATES=$'  candidates:\n    - '"${WEBRTC_IP}:8555"
    bashio::log.info "WebRTC candidate: ${WEBRTC_IP}:8555"
else
    WEBRTC_CANDIDATES=""
    bashio::log.warning "webrtc_ip not set — WebRTC off, players fall back to MSE"
fi

CONFIG="/tmp/go2rtc.yaml"
cat > "${CONFIG}" <<EOF
log:
  level: info
api:
  listen: ":1984"
rtsp:
  listen: ":8554"
webrtc:
  listen: ":8555"
${WEBRTC_CANDIDATES}
streams:
EOF

# One go2rtc stream per configured camera. ctv_client emits H.264 Annex-B on
# stdout; ffmpeg re-encodes it into the go2rtc RTSP listener ({output}). Two
# things are essential for a smooth WebRTC/HLS stream:
#   * -probesize/-analyzeduration caps — the raw Annex-B stream has no
#     timestamps and a low bitrate, so ffmpeg's default 5 MB probe stalls
#     ~28-40s before the first frame. Capping it cuts startup to ~2s.
#   * -use_wallclock_as_timestamps + re-encode to constant 15 fps with a
#     keyframe every second (-r 15 -g 15) — the doorbell sends a low, VARIABLE
#     frame rate with irregular keyframes (every 3-7s). With -c:v copy and a
#     fixed -r, players saw bogus timings and, on any packet loss, froze 15-30s
#     waiting for the next keyframe. Wall-clock PTS fix the timing; a steady CFR
#     with a 1s keyframe lets WebRTC recover in ~1s. The re-encode is tiny
#     (640x480, ultrafast) — negligible on any host. (Note: keep the ffmpeg
#     args free of shell metacharacters like () — go2rtc runs them via bash -c.)
NAMES=()
for i in $(bashio::config 'cameras|keys'); do
    CH="$(bashio::config "cameras[${i}].channel")"
    NAME="$(bashio::config "cameras[${i}].name")"
    NAMES+=("${NAME}")
    bashio::log.info "Camera '${NAME}' -> doorbell channel ${CH}"
    {
        echo "  ${NAME}:"
        echo "    - \"exec:bash -c 'python3 /ctv_client.py --channel ${CH} | ffmpeg -hide_banner -loglevel error -probesize 32768 -analyzeduration 0 -use_wallclock_as_timestamps 1 -fflags nobuffer -f h264 -i - -c:v libx264 -preset ultrafast -tune zerolatency -r 15 -g 15 -keyint_min 15 -sc_threshold 0 -pix_fmt yuv420p -an -rtsp_transport tcp -f rtsp {output}'#killsignal=15\""
    } >> "${CONFIG}"
done

# Preload every stream at startup and keep it connected. go2rtc is on-demand by
# default: it drops the doorbell connection when nobody watches and reconnects
# (a few seconds) on the next request — long enough for Home Assistant's 10s
# snapshot timeout to fire. Preloading keeps each channel warm so snapshots and
# previews return immediately. Video only — the stream carries no audio.
{
    echo "preload:"
    for NAME in "${NAMES[@]}"; do
        echo "  ${NAME}: \"video\""
    done
} >> "${CONFIG}"

bashio::log.info "Starting go2rtc (RTSP :8554, WebUI :1984)"
exec go2rtc -config "${CONFIG}"
