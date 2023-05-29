#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ $(which readlink | wc -l) -eq 1 ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi
scriptPath=$(cd -P "$(dirname "${scriptFileName}")" && pwd)

applicationVersion=
force=
source "${scriptPath}/prepare-parameters.sh"

echo "Preparing distribution detection"

if ! [[ -x "$(command -v lsb_release)" ]]; then
  echo "Installing lsb_release"
  distribution=$(awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"')

  if [[ "${distribution}" == "CentOS Linux" ]]; then
    yum check-update
    yum swap -y fakesystemd systemd
    yum clean all
    yum install -y redhat-lsb-core
  elif [[ "${distribution}" == "Debian GNU/Linux" ]]; then
    apt-get update
    apt-get install -y lsb-release
  elif [[ "${distribution}" == "Fedora" ]]; then
    dnf check-update
    dnf install -y redhat-lsb
  elif [[ "${distribution}" == "Manjaro Linux" ]]; then
    pacman -Fy
    yes | LANG=C pacman -S lsb-release
  elif [[ "${distribution}" == "openSUSE Leap" ]]; then
    zypper refresh
    zypper install --no-confirm lsb-release
  elif [[ "${distribution}" == "Red Hat Enterprise Linux" ]]; then
    yum check-update
    yum install -y redhat-lsb-core
  elif [[ "${distribution}" == "Ubuntu" ]]; then
    apt-get update
    apt-get install -y lsb-release
  fi
fi

if [[ -n "${applicationVersion}" ]]; then
  "${scriptPath}/install.sh" \
    --applicationName "Cosyses" \
    --applicationVersion "${applicationVersion}" \
    --applicationScript "packages.sh"
else
  "${scriptPath}/install.sh" \
    --applicationName "Cosyses" \
    --applicationScript "packages.sh"
fi

if [[ -n "${applicationVersion}" ]]; then
  if [[ "${force}" == 1 ]]; then
    "${scriptPath}/install.sh" \
      --applicationName "Cosyses" \
      --applicationVersion "${applicationVersion}" \
      --force
  else
    "${scriptPath}/install.sh" \
      --applicationName "Cosyses" \
      --applicationVersion "${applicationVersion}"
  fi
else
  if [[ "${force}" == 1 ]]; then
    "${scriptPath}/install.sh" \
      --applicationName "Cosyses" \
      --force
  else
    "${scriptPath}/install.sh" \
      --applicationName "Cosyses"
  fi
fi
