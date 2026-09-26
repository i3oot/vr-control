#!/usr/bin/env bash
set -Eeuo pipefail

trap 'status=$?; if (( status != 0 )); then printf "\nVR setup stopped with an error (exit %s). Review the message above and run setup again.\n" "$status"; fi' EXIT

if ! command -v yay >/dev/null 2>&1; then
  echo "The yay AUR helper is required to install WiVRn, WayVR, and XRizer."
  exit 1
fi

if ! command -v omarchy >/dev/null 2>&1; then
  echo "This setup flow requires Omarchy's package commands."
  exit 1
fi

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-vr"
baseline_file="$state_dir/before-setup.conf"
latest_file="$state_dir/after-setup.conf"
mkdir -p -- "$state_dir"
chmod 700 "$state_dir"

package_state() {
  pacman -Qq "$1" >/dev/null 2>&1 && printf installed || printf missing
}

unit_state() {
  local scope=$1 verb=$2 unit=$3 value
  if [[ $scope == user ]]; then
    value=$(systemctl --user "$verb" "$unit" 2>/dev/null) || value=unknown
  else
    value=$(systemctl "$verb" "$unit" 2>/dev/null) || value=unknown
  fi
  printf '%s' "${value:-unknown}"
}

write_snapshot() {
  local destination=$1 phase=$2 temporary
  temporary=$(mktemp "$state_dir/.snapshot.XXXXXX")
  {
    printf 'recorded_at=%s\n' "$(date --iso-8601=seconds)"
    printf 'phase=%s\n' "$phase"
    for package in wivrn-dashboard wayvr xrizer avahi; do
      printf 'package.%s=%s\n' "$package" "$(package_state "$package")"
    done
    printf 'service.wivrn.enabled=%s\n' "$(unit_state user is-enabled wivrn.service)"
    printf 'service.wivrn.active=%s\n' "$(unit_state user is-active wivrn.service)"
    printf 'service.avahi.enabled=%s\n' "$(unit_state system is-enabled avahi-daemon.service)"
    printf 'service.avahi.active=%s\n' "$(unit_state system is-active avahi-daemon.service)"
  } > "$temporary"
  chmod 600 "$temporary"
  mv -f -- "$temporary" "$destination"
}

# Keep the original baseline across repeated setup runs so a later removal can
# distinguish components that predated this plugin from ones setup added.
if [[ ! -f $baseline_file ]]; then
  write_snapshot "$baseline_file" before
fi

echo "Installing WiVRn, WayVR, and XRizer from the AUR. Review the package prompts."
yay -S --needed wivrn-dashboard wayvr xrizer

echo "Installing Avahi from the Omarchy package repositories."
omarchy pkg add avahi

echo "Enabling headset discovery on the local network."
sudo systemctl enable --now avahi-daemon.service

echo "Enabling the WiVRn user service for this account."
systemctl --user enable --now wivrn.service

write_snapshot "$latest_file" after

echo
echo "VR setup is ready. Open the WiVRn dashboard to finish headset pairing."
