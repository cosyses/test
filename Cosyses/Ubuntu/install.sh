#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ $(which readlink | wc -l) -eq 1 ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi
scriptPath=$(cd -P "$(dirname "${scriptFileName}")" && pwd)

applicationVersion=
force=
source "${scriptPath}/../../../prepare-parameters.sh"

basePath="/usr/local/lib/cosyses"
currentReleasePath="${basePath}/current"
if [[ -n "${applicationVersion}" ]]; then
  gitReleaseUrl="https://api.github.com/repos/cosyses/test/releases/tags/${applicationVersion}"
else
  gitReleaseUrl="https://api.github.com/repos/cosyses/test/releases/latest"
fi

echo "Determining release data"
releaseData=$(curl -s "${gitReleaseUrl}" 2>/dev/null | cat)
if [[ -z "${releaseData}" ]]; then
  counter=0
  until [[ "${counter}" -gt 20 ]]; do
    ((counter++))
    >&2 echo "Could not determine release data. Waiting three seconds to avoid too many requests timeout."
    sleep 3
    echo "Determining release data (retry #${counter})"
    releaseData=$(curl -s "${gitReleaseUrl}" 2>/dev/null | cat)
    if [[ -n "${releaseData}" ]]; then
      break;
    fi
  done
fi

if [[ -z "${releaseData}" ]]; then
  >&2 echo "Could not determine release data."
  exit 1
fi

releaseVersion=$(echo "${releaseData}" | jq -r '.tag_name')
echo "Release version: ${releaseVersion}"

if [[ ! -d "${basePath}" ]]; then
  echo "Creating base path at: ${basePath}"
  mkdir -p "${basePath}"
fi

releasePath="${basePath}/${releaseVersion}"

if [[ -d "${releasePath}" ]] && [[ "${force}" == 1 ]]; then
  echo "Removing previously installed release"
  rm -rf "${releasePath}"
fi

if [[ -d "${releasePath}" ]]; then
  echo "Release already installed"
else
  releaseZipUrl=$(echo "${releaseData}" | jq -r '.zipball_url')
  releaseZipPath="${basePath}/${releaseVersion}.zip"

  echo "Downloading release archive from url: ${releaseZipUrl}"
  result=$(wget -q -O "${releaseZipPath}" "${releaseZipUrl}" 2>&1 | cat)

  if [[ ! -f "${releaseZipPath}" ]]; then
    if [[ "${result}" =~ "ERROR 429" ]]; then
      counter=0
      until [[ "${counter}" -gt 20 ]]; do
        ((counter++))
        echo "Could not download release archive. Waiting three seconds to avoid too many requests timeout"
        sleep 3
        echo "Downloading release archive from url: ${releaseZipUrl} (retry #${counter})"
        result=$(wget -q -O "${releaseZipPath}" "${releaseZipUrl}" 2>&1 | cat)
        if [[ -f "${releaseZipPath}" ]]; then
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

  if [[ ! -f "${releaseZipPath}" ]]; then
    >&2 echo "Download failed"
    exit 1
  fi

  echo "Extracting downloaded release archive"
  unzip -j -o -q "${releaseZipPath}" -d "${releasePath}"

  echo "Release archive extracted to: ${releasePath}"

  echo "Removing downloaded release archive"
  rm -rf "${releaseZipPath}"

  if [[ -L "${currentReleasePath}" ]]; then
    echo "Unlinking currently installed release"
    rm "${currentReleasePath}"
  fi

  echo "Linking installed release from: ${releasePath} to: ${currentReleasePath}"
  ln -s "${releasePath}" "${currentReleasePath}"
fi
