#!/bin/bash -e

awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"'

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ $(which readlink | wc -l) -eq 1 ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi
scriptPath=$(cd -P "$(dirname "${scriptFileName}")" && pwd)

force=
source "${scriptPath}/prepare-parameters.sh"

echo "Installing cosyses"

requiredPackages=( curl jq wget unzip )
basePath="/usr/local/lib/cosyses"
currentReleasePath="${basePath}/current"
gitLatestReleaseUrl="https://api.github.com/repos/cosyses/test/releases/latest"

if [[ $(which install-package | wc -l) -eq 1 ]]; then
  echo "Using custom install function"
  customInstall=1
else
  echo "Using native install function"
  customInstall=0
fi

for requiredPackage in "${requiredPackages[@]}"; do
  if [[ $(which "${requiredPackage}" | wc -l) -eq 0 ]]; then
    echo "Installing ${requiredPackage}"
    if [[ "${customInstall}" == 1 ]]; then
      install-package "${requiredPackage}"
    else
      UCF_FORCE_CONFOLD=1 DEBIAN_FRONTEND=noninteractive sudo apt-get install -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages "${requiredPackage}" 2>&1
    fi
  else
    echo "${requiredPackage} already installed."
  fi
done

echo "Determining latest release"
latestReleaseData=$(curl -s "${gitLatestReleaseUrl}" 2>/dev/null | cat)
if [[ -z "${latestReleaseData}" ]]; then
  counter=0
  until [[ "${counter}" -gt 20 ]]; do
    ((counter++))
    >&2 echo "Could not determine latest release. Waiting three seconds to avoid too many requests timeout."
    sleep 3
    echo "Determining latest release (retry #${counter})"
    latestReleaseData=$(curl -s "${gitLatestReleaseUrl}" 2>/dev/null | cat)
    if [[ -n "${latestReleaseData}" ]]; then
      break;
    fi
  done
fi

if [[ -z "${latestReleaseData}" ]]; then
  >&2 echo "Could not determine latest release."
  exit 1
fi

latestReleaseVersion=$(echo "${latestReleaseData}" | jq -r '.tag_name')
echo "Latest release version: ${latestReleaseVersion}"

if [[ ! -d "${basePath}" ]]; then
  echo "Creating base path at: ${basePath}"
  sudo mkdir -p "${basePath}"
fi

latestReleasePath="${basePath}/${latestReleaseVersion}"

if [[ -d "${latestReleasePath}" ]] && [[ "${force}" == 1 ]]; then
  echo "Removing latest release"
  sudo rm -rf "${latestReleasePath}"
fi

if [[ -d "${latestReleasePath}" ]]; then
  echo "Latest release already downloaded"
else
  latestReleaseZipUrl=$(echo "${latestReleaseData}" | jq -r '.zipball_url')
  latestReleaseZipPath="${basePath}/${latestReleaseVersion}.zip"

  echo "Downloading latest release: ${latestReleaseZipUrl}"
  result=$(sudo wget -q -O "${latestReleaseZipPath}" "${latestReleaseZipUrl}" 2>&1 | cat)

  if [[ ! -f "${latestReleaseZipPath}" ]]; then
    if [[ "${result}" =~ "ERROR 429" ]]; then
      counter=0
      until [[ "${counter}" -gt 20 ]]; do
        ((counter++))
        echo "Could not download latest release. Waiting three seconds to avoid too many requests timeout"
        sleep 3
        echo "Downloading latest version: ${latestReleaseZipUrl} (retry #${counter})"
        result=$(sudo wget -q -O "${latestReleaseZipPath}" "${latestReleaseZipUrl}" 2>&1 | cat)
        if [[ -f "${latestReleaseZipPath}" ]]; then
          break;
        fi
        if ! [[ "${result}" =~ "ERROR 429" ]]; then
          >&2 echo "${result}"
          exit 1
        fi
      done
    else
      >&2 echo "${result}"
      exit 1
    fi
  fi

  if [[ ! -f "${latestReleaseZipPath}" ]]; then
    >&2 echo "Download failed"
    exit 1
  fi

  echo "Extracting latest release download"
  sudo unzip -j -o -q "${latestReleaseZipPath}" -d "${latestReleasePath}"

  echo "Latest release downloaded to: ${latestReleasePath}"

  echo "Removing download"
  sudo rm -rf "${latestReleaseZipPath}"

  if [[ -L "${currentReleasePath}" ]]; then
    echo "Unlinking current release"
    sudo rm "${currentReleasePath}"
  fi

  echo "Linking latest release to: ${currentReleasePath}"
  sudo ln -s "${latestReleasePath}" "${currentReleasePath}"
fi

echo "Finished installing cosyses"
