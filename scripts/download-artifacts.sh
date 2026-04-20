#!/usr/bin/env bash
set -o nounset -o errexit -o pipefail

STACK_VERSION="${STACK_VERSION:?Make sure to set STACK_VERSION when running this script}"
ARTIFACT_DOWNLOADS_BASE_URL="${ARTIFACT_DOWNLOADS_BASE_URL:-https://artifacts.elastic.co/downloads}"
DOWNLOAD_BASE_DIR="${DOWNLOAD_BASE_DIR:?Make sure to set DOWNLOAD_BASE_DIR when running this script}"

LINUX_PACKAGE_PREFIXES=(
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

WINDOWS_PACKAGE_PREFIXES=(
  "apm-server/apm-server"
  "beats/auditbeat/auditbeat"
  "beats/elastic-agent/elastic-agent"
  "beats/filebeat/filebeat"
  "beats/heartbeat/heartbeat"
  "beats/metricbeat/metricbeat"
  "beats/osquerybeat/osquerybeat"
  "beats/packetbeat/packetbeat"
)

WINDOWS_OPTIONAL_PACKAGE_PREFIXES=(
  "beats/winlogbeat/winlogbeat"
)

RPM_PACKAGES=(
  "beats/elastic-agent/elastic-agent"
)

DEB_PACKAGES=(
  "beats/elastic-agent/elastic-agent"
)

REQUIRED_MISSING_ARTIFACTS=()
OPTIONAL_MISSING_ARTIFACTS=()
FAILED_DOWNLOADS=()

download_artifact() {
  local dl_url="$1"
  local output_path="$2"
  local required="$3"
  local http_code=""
  local curl_exit_code=0

  echo "[INFO] Downloading ${dl_url}"

  set +o errexit
  http_code="$(
    curl \
      --location \
      --silent \
      --show-error \
      --output "${output_path}" \
      --write-out "%{http_code}" \
      "${dl_url}"
  )"
  curl_exit_code=$?
  set -o errexit

  if [[ "${curl_exit_code}" -ne 0 ]]; then
    rm -f "${output_path}"
    FAILED_DOWNLOADS+=("${dl_url} (curl exit ${curl_exit_code})")
    echo "[ERROR] curl failed for ${dl_url} with exit code ${curl_exit_code}" >&2
    return 0
  fi

  if [[ "${http_code}" =~ ^2[0-9][0-9]$ ]]; then
    return 0
  fi

  rm -f "${output_path}"

  if [[ "${http_code}" == "404" ]]; then
    if [[ "${required}" == "true" ]]; then
      REQUIRED_MISSING_ARTIFACTS+=("${dl_url}")
      echo "[ERROR] Missing required artifact (HTTP 404): ${dl_url}" >&2
    else
      OPTIONAL_MISSING_ARTIFACTS+=("${dl_url}")
      echo "[WARN] Missing optional artifact (HTTP 404): ${dl_url}" >&2
    fi
    return 0
  fi

  FAILED_DOWNLOADS+=("${dl_url} (HTTP ${http_code})")
  echo "[ERROR] Failed to download ${dl_url} with HTTP status ${http_code}" >&2
}

download_packages() {
  local url_suffix="$1"
  local required="$2"
  shift
  shift
  local package_prefixes=("$@")
  local pkg_dir=""
  local dl_url=""
  local output_path=""

  for download_prefix in "${package_prefixes[@]}"; do
    for pkg_url_suffix in "$url_suffix" "${url_suffix}.sha512" "${url_suffix}.asc"; do
      pkg_dir="$(dirname "${DOWNLOAD_BASE_DIR}/${download_prefix}")"
      dl_url="${ARTIFACT_DOWNLOADS_BASE_URL}/${download_prefix}-${pkg_url_suffix}"
      output_path="${pkg_dir}/$(basename "${dl_url}")"
      mkdir -p "${pkg_dir}"
      download_artifact "${dl_url}" "${output_path}" "${required}"
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

  if [[ "${os_name}" == "linux" ]]; then
    download_packages "${pkg_url_suffix}" "true" "${LINUX_PACKAGE_PREFIXES[@]}"
    download_packages "${STACK_VERSION}-x86_64.rpm" "true" "${RPM_PACKAGES[@]}"
    download_packages "${STACK_VERSION}-amd64.deb" "true" "${DEB_PACKAGES[@]}"
  elif [[ "${os_name}" == "windows" ]]; then
    download_packages "${pkg_url_suffix}" "true" "${WINDOWS_PACKAGE_PREFIXES[@]}"
    download_packages "${pkg_url_suffix}" "false" "${WINDOWS_OPTIONAL_PACKAGE_PREFIXES[@]}"
  fi
done

if (( ${#OPTIONAL_MISSING_ARTIFACTS[@]} > 0 )); then
  echo "[WARN] Optional artifacts missing:" >&2
  for artifact_url in "${OPTIONAL_MISSING_ARTIFACTS[@]}"; do
    echo "[WARN]   ${artifact_url}" >&2
  done
fi

if (( ${#REQUIRED_MISSING_ARTIFACTS[@]} > 0 )); then
  echo "[ERROR] Required artifacts missing:" >&2
  for artifact_url in "${REQUIRED_MISSING_ARTIFACTS[@]}"; do
    echo "[ERROR]   ${artifact_url}" >&2
  done
fi

if (( ${#FAILED_DOWNLOADS[@]} > 0 )); then
  echo "[ERROR] Downloads failed:" >&2
  for failure in "${FAILED_DOWNLOADS[@]}"; do
    echo "[ERROR]   ${failure}" >&2
  done
fi

if (( ${#REQUIRED_MISSING_ARTIFACTS[@]} > 0 || ${#FAILED_DOWNLOADS[@]} > 0 )); then
  exit 1
fi
