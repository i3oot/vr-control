#!/usr/bin/env bash
set -Eeuo pipefail

operation=${1:-}
if [[ $operation != open && $operation != close && $operation != remove ]]; then
  echo "Usage: $0 open|close|remove" >&2
  exit 2
fi

if (( EUID != 0 )); then
  exec sudo -- "$0" "$operation"
fi

sudoers_file=/etc/sudoers.d/omarchy-vr-control

if [[ $operation == remove ]]; then
  if command -v ufw >/dev/null 2>&1 && grep -qx 'ENABLED=yes' /etc/ufw/ufw.conf && systemctl is-active --quiet ufw; then
    tag="Omarchy VR Control"
    mapfile -t rule_numbers < <(
      ufw status numbered |
        awk -v tag="$tag" 'index($0, "# " tag) && match($0, /\[[[:space:]]*[0-9]+\]/) {
          number = substr($0, RSTART, RLENGTH)
          gsub(/[^0-9]/, "", number)
          print number
        }' |
        sort -rn
    )
    for number in "${rule_numbers[@]}"; do
      ufw --force delete "$number"
    done
    if ((${#rule_numbers[@]})); then
      echo "Removed Omarchy VR Control firewall rules. Other rules were left unchanged."
    else
      echo "No Omarchy VR Control firewall rules to remove."
    fi
  else
    echo "UFW is absent or inactive; no firewall rules needed changing."
  fi
  if [[ -e $sudoers_file ]]; then
    rm -f -- "$sudoers_file"
    echo "Removed the plugin's read-only UFW status permission."
  fi
  exit 0
fi

if ! command -v ufw >/dev/null 2>&1; then
  echo "UFW is not installed; no firewall rules were changed."
  exit 1
fi

if ! grep -qx 'ENABLED=yes' /etc/ufw/ufw.conf || ! systemctl is-active --quiet ufw; then
  echo "UFW is not active; no firewall rules were changed."
  exit 1
fi

install_status_permission() {
  local username=${SUDO_USER:-}
  local ufw_path sudoers_file temporary_file rule
  if [[ ! $username =~ ^[a-zA-Z0-9_.-]+$ ]]; then
    echo "Could not determine the invoking user for the read-only UFW status permission." >&2
    exit 1
  fi
  ufw_path=$(command -v ufw)
  rule="$username ALL=(root) NOPASSWD: $ufw_path status numbered"
  if [[ -f $sudoers_file ]] && grep -Fxq "$rule" "$sudoers_file"; then
    return
  fi

  temporary_file=$(mktemp /etc/sudoers.d/omarchy-vr-control.XXXXXX)
  printf '%s\n' "$rule" > "$temporary_file"
  chown root:root "$temporary_file"
  chmod 0440 "$temporary_file"
  if ! visudo -cf "$temporary_file"; then
    rm -f "$temporary_file"
    exit 1
  fi
  mv "$temporary_file" "$sudoers_file"
  if ! visudo -c; then
    rm -f "$sudoers_file"
    visudo -c || true
    exit 1
  fi
  echo "Installed a read-only sudo permission for: $ufw_path status numbered"
}

install_status_permission

tag="Omarchy VR Control"
networks=("10.0.0.0/8" "172.16.0.0/12" "192.168.0.0/16" "fc00::/7")
rules=("9757 tcp" "9757 udp" "5353 udp")

if [[ $operation == open ]]; then
  echo "Allowing WiVRn traffic from private LAN address ranges only."
  for network in "${networks[@]}"; do
    for rule in "${rules[@]}"; do
      read -r port protocol <<< "$rule"
      status=$(ufw status)
      if awk -v rule="$port/$protocol" -v network="$network" \
        '$1 == rule && $2 == "ALLOW" && $3 == "IN" && $4 == network { found = 1 }
         END { exit !found }' <<< "$status"; then
        echo "Existing $port/$protocol rule for $network left unchanged."
        continue
      fi
      ufw allow from "$network" to any port "$port" proto "$protocol" comment "$tag"
    done
  done
  echo "WiVRn LAN firewall rules are ready."
else
  mapfile -t rule_numbers < <(
    ufw status numbered |
      awk -v tag="$tag" 'index($0, "# " tag) && match($0, /\[[[:space:]]*[0-9]+\]/) {
        number = substr($0, RSTART, RLENGTH)
        gsub(/[^0-9]/, "", number)
        print number
      }' |
      sort -rn
  )
  if ((${#rule_numbers[@]} == 0)); then
    echo "No Omarchy VR Control firewall rules to remove."
  else
    for number in "${rule_numbers[@]}"; do
      ufw --force delete "$number"
    done
    echo "Removed Omarchy VR Control rules. Other firewall rules were left unchanged."
  fi
fi
