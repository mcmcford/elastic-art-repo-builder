#!/usr/bin/env bash
set -o nounset -o errexit -o pipefail

STACK_VERSION="${STACK_VERSION:?Make sure to set STACK_VERSION when running this script}"
ARTIFACT_DOWNLOADS_BASE_URL="${ARTIFACT_DOWNLOADS_BASE_URL:-https://artifacts.elastic.co/downloads}"
DOWNLOAD_BASE_DIR="${DOWNLOAD_BASE_DIR:?Make sure to set DOWNLOAD_BASE_DIR when running this script}"

COMMON_PACKAGE_PREFIXES=(
  "apm-server/apm-server"
  "beats/auditbeat/auditbeat"
  "beats/elastic-agent/elastic-agent"
  "beats/filebeat/filebeat"
  "beats/heartbeat/heartbeat"
  "beats/metricbeat/metricbeat"
  "beats/osquerybeat/osquerybeat"
  "beats/packetbeat/packetbeat"
  "cloudbeat/cloudbeat"
  "endpoint-dev/endpoint-security"
  "fleet-server/fleet-server"
)

WIN_ONLY_PACKAGE_PREFIXES=(
  "beats/winlogbeat/winlogbeat"
)

RPM_PACKAGES=(
  "beats/elastic-agent/elastic-agent"
)

DEB_PACKAGES=(
  "beats/elastic-agent/elastic-agent"
)

download_packages() {
  local url_suffix="$1"
  shift
  local package_prefixes=("$@")
  local pkg_dir=""
  local dl_url=""

  for download_prefix in "${package_prefixes[@]}"; do
    for pkg_url_suffix in "$url_suffix" "${url_suffix}.sha512" "${url_suffix}.asc"; do
      pkg_dir="$(dirname "${DOWNLOAD_BASE_DIR}/${download_prefix}")"
      dl_url="${ARTIFACT_DOWNLOADS_BASE_URL}/${download_prefix}-${pkg_url_suffix}"
      mkdir -p "${pkg_dir}"
      curl --fail --location --output "${pkg_dir}/$(basename "${dl_url}")" "${dl_url}"
    done
  done
}

for os_name in linux windows; do
  case "${os_name}" in
    linux)
      pkg_url_suffix="${STACK_VERSION}-${os_name}-x86_64.tar.gz"
      ;;
    windows)
      pkg_url_suffix="${STACK_VERSION}-${os_name}-x86_64.zip"
      ;;
    *)
      echo "[ERROR] Unsupported operating system: ${os_name}" >&2
      exit 1
      ;;
  esac

  download_packages "${pkg_url_suffix}" "${COMMON_PACKAGE_PREFIXES[@]}"

  if [[ "${os_name}" == "windows" ]]; then
    download_packages "${pkg_url_suffix}" "${WIN_ONLY_PACKAGE_PREFIXES[@]}"
  fi

  if [[ "${os_name}" == "linux" ]]; then
    download_packages "${STACK_VERSION}-x86_64.rpm" "${RPM_PACKAGES[@]}"
    download_packages "${STACK_VERSION}-amd64.deb" "${DEB_PACKAGES[@]}"
  fi
done
