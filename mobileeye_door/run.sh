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
streams:
EOF

# One go2rtc stream per configured camera. ctv_client emits H.264 Annex-B on
# stdout, ffmpeg remuxes it (stream copy, no re-encode) into the go2rtc RTSP
# listener ({output}). The -probesize/-analyzeduration caps are essential: the
# raw Annex-B stream carries no timestamps and has a low bitrate, so ffmpeg's
# default stream probe (5 MB) keeps analysing for ~28-40s before it emits the
# first frame, and snapshots/previews time out. Capping the probe cuts startup
# to ~2s. The doorbell already sends frequent keyframes, so no re-encode needed.
for i in $(bashio::config 'cameras|keys'); do
    CH="$(bashio::config "cameras[${i}].channel")"
    NAME="$(bashio::config "cameras[${i}].name")"
    bashio::log.info "Camera '${NAME}' -> doorbell channel ${CH}"
    {
        echo "  ${NAME}:"
        echo "    - \"exec:bash -c 'python3 /ctv_client.py --channel ${CH} | ffmpeg -hide_banner -loglevel error -probesize 32768 -analyzeduration 0 -fflags nobuffer -f h264 -r 25 -i - -c:v copy -rtsp_transport tcp -f rtsp {output}'#killsignal=15\""
    } >> "${CONFIG}"
done

bashio::log.info "Starting go2rtc (RTSP :8554, WebUI :1984)"
exec go2rtc -config "${CONFIG}"
