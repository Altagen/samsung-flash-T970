# shellcheck shell=bash
# Pinned third-party downloads: official source first, project mirror second.
# Source this file, then: fetch_artifact NAME  ->  downloads/NAME
#
# - The expected SHA-256 comes from SHA256SUMS (repo root), the single source of truth.
# - The official URL is tried first. If it is dead, or serves a different file
#   (e.g. a nightly build that moved on), the copy in the project's GitHub
#   release (v1.0.0) is used instead.
# - Whatever the source, a file that does not match SHA256SUMS is never kept.

FETCH_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MIRROR_BASE="${MIRROR_BASE:-https://github.com/Altagen/samsung-flash-T970/releases/download/v1.0.0}"

# Official locations. Empty = no stable official URL (mirror only, or manual).
declare -A OFFICIAL_URL=(
    [twrp-gts7xl-3.6.0_11-A12-1a7_ianmacd.img]=""     # XDA thread only
    [Magisk-v30.7.apk]="https://github.com/topjohnwu/Magisk/releases/download/v30.7/Magisk-v30.7.apk"
    [T970XXS7DXH1-boot.img.lz4]=""                    # inside Samsung's 7.6 GB firmware (AP_ file)
    [android_kernel_samsung_sm8250-4910fe83f.tar.xz]="" # official source is git (kernel/get-sources.sh)
    [docker-27.3.1.tgz]="https://download.docker.com/linux/static/stable/aarch64/docker-27.3.1.tgz"
    [docker-compose-arm64]="https://github.com/docker/compose/releases/download/v2.32.4/docker-compose-linux-aarch64"
    [podman-linux-arm64.tar.gz]="https://github.com/mgoltzsche/podman-static/releases/download/v5.8.1/podman-linux-arm64.tar.gz"
    [termux_1022.apk]="https://f-droid.org/repo/com.termux_1022.apk"
    [termux-x11-arm64.apk]="https://github.com/termux/termux-x11/releases/download/nightly/app-arm64-v8a-debug.apk"
    [ubuntu-base-arm64.tar.gz]="https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.4-base-arm64.tar.gz"
    [connectbot_11101000.apk]="https://f-droid.org/repo/org.connectbot_11101000.apk"
)

# Every artifact known to fetch_artifact, in the order fetch-downloads.sh uses.
# shellcheck disable=SC2034  # used by the scripts that source this file
ARTIFACTS=(
    twrp-gts7xl-3.6.0_11-A12-1a7_ianmacd.img
    Magisk-v30.7.apk
    T970XXS7DXH1-boot.img.lz4
    docker-27.3.1.tgz
    docker-compose-arm64
    podman-linux-arm64.tar.gz
    termux_1022.apk
    termux-x11-arm64.apk
    ubuntu-base-arm64.tar.gz
    connectbot_11101000.apk
)

expected_sha256() {
    awk -v f="downloads/$1" '$2 == f { print $1 }' "$FETCH_REPO_ROOT/SHA256SUMS"
}

sha256_ok() {   # FILE SHA
    [ -f "$1" ] && [ "$(sha256sum "$1" | cut -d' ' -f1)" = "$2" ]
}

fetch_artifact() {   # NAME
    local name="$1" sha dest url
    sha="$(expected_sha256 "$name")"
    [ -n "$sha" ] || { echo "  fetch: $name is not listed in SHA256SUMS" >&2; return 1; }
    dest="$FETCH_REPO_ROOT/downloads/$name"
    mkdir -p "$FETCH_REPO_ROOT/downloads"

    if sha256_ok "$dest" "$sha"; then
        echo "  ok      $name (already downloaded, checksum verified)"
        return 0
    fi

    for url in "${OFFICIAL_URL[$name]:-}" "$MIRROR_BASE/$name"; do
        [ -n "$url" ] || continue
        echo "  get     $name  <-  $url"
        if curl -fL --retry 2 --connect-timeout 15 -sS -o "$dest.part" "$url"; then
            if sha256_ok "$dest.part" "$sha"; then
                mv "$dest.part" "$dest"
                echo "  ok      $name (checksum verified)"
                return 0
            fi
            echo "  !!      $name: checksum mismatch from $url, trying next source" >&2
        else
            echo "  !!      $name: download failed from $url, trying next source" >&2
        fi
        rm -f "$dest.part"
    done

    echo "  FAILED  $name: no source served the expected file (sha256 $sha)" >&2
    return 1
}
