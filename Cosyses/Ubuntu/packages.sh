#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ $(which readlink | wc -l) -eq 1 ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi
scriptPath=$(cd -P "$(dirname "${scriptFileName}")" && pwd)

source "${scriptPath}/../../../prepare-parameters.sh"

requiredPackages=( curl jq wget unzip )

if [[ -x "$(command -v install-package)" ]]; then
  echo "Using custom install function"
  customInstall=1
else
  echo "Using native install function"
  customInstall=0
fi

for requiredPackage in "${requiredPackages[@]}"; do
  if [[ -x "$(command -v "${requiredPackage}")" ]]; then
    echo "Installing ${requiredPackage}"
    if [[ "${customInstall}" == 1 ]]; then
      install-package "${requiredPackage}"
    else
      apt-get install -y "${requiredPackage}" 2>&1
    fi
  else
    echo "${requiredPackage} already installed."
  fi
done
