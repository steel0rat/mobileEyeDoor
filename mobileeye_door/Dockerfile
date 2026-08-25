ARG BUILD_FROM
FROM ${BUILD_FROM}

ARG BUILD_ARCH
ARG GO2RTC_VERSION=1.9.14

RUN apk add --no-cache python3 ffmpeg bash

# go2rtc static binary, matched to the target architecture.
RUN set -eux; \
    case "${BUILD_ARCH}" in \
        aarch64) GA=arm64 ;; \
        amd64)   GA=amd64 ;; \
        armv7)   GA=arm ;; \
        armhf)   GA=armv6 ;; \
        i386)    GA=386 ;; \
        *) echo "unsupported arch ${BUILD_ARCH}" >&2; exit 1 ;; \
    esac; \
    wget -O /usr/bin/go2rtc \
        "https://github.com/AlexxIT/go2rtc/releases/download/v${GO2RTC_VERSION}/go2rtc_linux_${GA}"; \
    chmod +x /usr/bin/go2rtc

COPY ctv_client.py /ctv_client.py
COPY run.sh /run.sh
RUN chmod +x /run.sh /ctv_client.py

CMD ["/run.sh"]
