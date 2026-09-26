#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ! -t 0 ]]; then
  echo "Run this script in a terminal so you can choose what to remove." >&2
  exit 2
fi

ask() {
  local answer
  read -r -p "$1 [y/N] " answer
  [[ $answer =~ ^[Yy]([Ee][Ss])?$ ]]
}

echo "Omarchy VR component removal"
echo "The plugin itself is not removed by this script."
echo

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-vr"
declare -A baseline=() latest=()
if [[ -f $state_dir/before-setup.conf ]]; then
  while IFS='=' read -r key value; do baseline["$key"]=$value; done < "$state_dir/before-setup.conf"
fi
if [[ -f $state_dir/after-setup.conf ]]; then
  while IFS='=' read -r key value; do latest["$key"]=$value; done < "$state_dir/after-setup.conf"
fi

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
report_item() {
  local label=$1 key=$2 current=$3 old=${baseline[$2]:-not recorded} after=${latest[$2]:-not recorded}
  printf '  %-18s before setup: %-10s after setup: %-10s now: %s\n' "$label" "$old" "$after" "$current"
}

echo "Recorded component history (the setup baseline is preserved across reruns):"
if ((${#baseline[@]} == 0)); then
  echo "  No setup history found. Current state is shown; prior ownership is unknown."
fi
report_item "WiVRn dashboard" package.wivrn-dashboard "$(package_state wivrn-dashboard)"
report_item "WayVR" package.wayvr "$(package_state wayvr)"
report_item "XRizer" package.xrizer "$(package_state xrizer)"
report_item "Avahi package" package.avahi "$(package_state avahi)"
report_item "WiVRn enabled" service.wivrn.enabled "$(unit_state user is-enabled wivrn.service)"
report_item "WiVRn active" service.wivrn.active "$(unit_state user is-active wivrn.service)"
report_item "Avahi enabled" service.avahi.enabled "$(unit_state system is-enabled avahi-daemon.service)"
report_item "Avahi active" service.avahi.active "$(unit_state system is-active avahi-daemon.service)"
if [[ -e /etc/sudoers.d/omarchy-vr-control ]]; then
  echo "  Firewall status permission: installed"
else
  echo "  Firewall status permission: absent"
fi
if firewall_status=$(sudo -n ufw status numbered 2>/dev/null); then
  firewall_rules=$(awk 'index($0, "# Omarchy VR Control") { count++ } END { print count+0 }' <<< "$firewall_status")
  printf '  Plugin firewall rules: %s currently present\n' "$firewall_rules"
else
  echo "  Plugin firewall rules: current status could not be read without a password"
fi
echo

if ask "Remove WiVRn, WayVR, and XRizer?"; then
  systemctl --user disable --now wivrn.service 2>/dev/null || true
  pkill -x wayvr 2>/dev/null || true

  packages=()
  for package in wivrn-dashboard wayvr xrizer; do
    if pacman -Qq "$package" >/dev/null 2>&1; then
      packages+=("$package")
    fi
  done

  if ((${#packages[@]})); then
    if command -v yay >/dev/null 2>&1; then
      yay -Rns "${packages[@]}"
    else
      echo "yay is required to remove the selected AUR packages: ${packages[*]}" >&2
    fi
  else
    echo "None of those packages are installed."
  fi
else
  echo "Keeping WiVRn, WayVR, and XRizer."
fi

if ask "Remove Avahi discovery service and package?"; then
  sudo systemctl disable --now avahi-daemon.service 2>/dev/null || true
  if pacman -Qq avahi >/dev/null 2>&1; then
    sudo pacman -Rns avahi
  else
    echo "Avahi is not installed."
  fi
else
  echo "Keeping Avahi."
fi

if ask "Remove plugin-managed firewall rules and its read-only status permission?"; then
  script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
  bash "$script_dir/firewall-control.sh" remove
else
  echo "Keeping firewall rules and status permission."
fi

echo
echo "Component cleanup finished. Remove the plugin separately with:"
echo "  omarchy plugin remove i3oot.vr"
