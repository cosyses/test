#!/bin/bash -e

applicationVersion=
force=0

declare -Ag prepareParameters
unparsedParameters=( )
while [[ "$#" -gt 0 ]]; do
  parameter="${1}"
  shift
  if [[ "${parameter:0:2}" == "--" ]] || [[ "${parameter}" =~ ^-[[:alpha:]][[:space:]]+ ]] || [[ "${parameter}" =~ ^-\?$ ]]; then
    if [[ "${parameter}" =~ ^--[[:alpha:]]+[[:space:]]+ ]]; then
      parameter="${parameter:2}"
      prepareParametersKey=$(echo "${parameter}" | grep -oP '[[:alpha:]]+(?=\s)' | tr -d "\n")
      prepareParametersValue=$(echo "${parameter:${#prepareParametersKey}}" | xargs)
      # shellcheck disable=SC2034
      prepareParameters["${prepareParametersKey}"]="${prepareParametersValue}"
      #echo eval "${prepareParametersKey}=\"${prepareParametersValue}\""
      eval "${prepareParametersKey}=\"${prepareParametersValue}\""
      continue
    fi
    if [[ "${parameter:0:2}" == "--" ]]; then
      prepareParametersKey="${parameter:2}"
    elif [[ "${parameter}" =~ ^-\?$ ]]; then
      prepareParametersKey="help"
    else
      prepareParametersKey="${parameter:1}"
    fi
    if [[ "$#" -eq 0 ]]; then
      prepareParameters["${prepareParametersKey}"]=1
      #echo eval "${prepareParametersKey}=1"
      eval "${prepareParametersKey}=1"
    else
      prepareParametersValue="${1}"
      if [[ "${prepareParametersValue:0:2}" == "--" ]]; then
        prepareParameters["${prepareParametersKey}"]=1
        #echo eval "${prepareParametersKey}=1"
        eval "${prepareParametersKey}=1"
        continue
      fi
      shift
      # shellcheck disable=SC2034
      prepareParameters["${prepareParametersKey}"]="${prepareParametersValue}"
      #echo eval "${prepareParametersKey}=\"${prepareParametersValue}\""
      eval "${prepareParametersKey}=\"${prepareParametersValue}\""
    fi
  else
    unparsedParameters+=("${parameter}")
  fi
done
set -- "${unparsedParameters[@]}"

prepareParametersList=()
for prepareParametersKey in "${!prepareParameters[@]}"; do
  prepareParametersList+=( "--${prepareParametersKey}" )
  prepareParametersValue="${prepareParameters[${prepareParametersKey}]}"
  prepareParametersList+=( "${prepareParametersValue}" )
done
for unparsedParametersKey in "${!unparsedParameters[@]}"; do
  unparsedParametersValue="${unparsedParameters[${unparsedParametersKey}]}"
  prepareParametersList+=( "${unparsedParametersValue}" )
done

distribution=$(awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"')

if [[ "${distribution}" == "Ubuntu" ]]; then
  basePath="/usr/local"
  libPath="${libPath}/lib"
  cosysesPath="${libPath}/cosyses"
  binPath="${basePath}/bin"
else
  >&2 echo "Unsupported OS: ${distribution}"
  exit 1
fi

currentReleasePath="${cosysesPath}/current"

alreadyInstalled=0

if [[ -n "${applicationVersion}" ]]; then
  releasePath="${cosysesPath}/${applicationVersion}"

  if [[ -d "${releasePath}" ]] && [[ "${force}" == 0 ]]; then
    echo "Release already installed"
    alreadyInstalled=1
  fi
fi

if [[ "${alreadyInstalled}" == 0 ]]; then
  echo "Preparing distribution detection"

  if ! [[ -x "$(command -v lsb_release)" ]]; then
    echo "Installing lsb_release"
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
    else
      >&2 echo "Unsupported OS: ${distribution}"
      exit 1
    fi
  fi

  echo "Finished preparing distribution detection"

  if [[ -x "$(command -v update-packages)" ]]; then
    echo "Using custom packages update function"
    customUpdate=1
  else
    echo "Using native packages update function"
    customUpdate=0
  fi

  if [[ "${customUpdate}" == 1 ]]; then
    update-packages
  else
    if [[ "${distribution}" == "Ubuntu" ]]; then
      apt-get update
      apt-get install -y "${requiredPackage}" 2>&1
    else
      >&2 echo "Unsupported OS: ${distribution}"
      exit 1
    fi
  fi

  if [[ -x "$(command -v install-package)" ]]; then
    echo "Using custom install function"
    customInstall=1
  else
    echo "Using native install function"
    customInstall=0
  fi

  if [[ "${distribution}" == "Ubuntu" ]]; then
    requiredPackages=( curl jq wget unzip )
  else
    >&2 echo "Unsupported OS: ${distribution}"
    exit 1
  fi

  for requiredPackage in "${requiredPackages[@]}"; do
    if [[ -x "$(command -v "${requiredPackage}")" ]]; then
      echo "Installing package: ${requiredPackage}"
      if [[ "${customInstall}" == 1 ]]; then
        install-package "${requiredPackage}"
      else
        if [[ "${distribution}" == "Ubuntu" ]]; then
          apt-get install -y "${requiredPackage}" 2>&1
        else
          >&2 echo "Unsupported OS: ${distribution}"
          exit 1
        fi
      fi
    else
      echo "${requiredPackage} already installed."
    fi
  done

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

  if [[ ! -d "${cosysesPath}" ]]; then
    echo "Creating base path at: ${cosysesPath}"
    mkdir -p "${cosysesPath}"
  fi

  releasePath="${cosysesPath}/${releaseVersion}"

  if [[ -d "${releasePath}" ]] && [[ "${force}" == 1 ]]; then
    echo "Removing previously installed release"
    rm -rf "${releasePath}"
  fi

  if [[ -d "${releasePath}" ]]; then
    echo "Release already installed"
  else
    releaseZipUrl=$(echo "${releaseData}" | jq -r '.zipball_url')
    releaseZipPath="${cosysesPath}/${releaseVersion}.zip"

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
  fi
fi

if [[ -L "${currentReleasePath}" ]]; then
  echo "Unlinking currently installed release"
  rm "${currentReleasePath}"
fi

echo "Linking installed release from: ${releasePath} to: ${currentReleasePath}"
ln -s "${releasePath}" "${currentReleasePath}"

if [[ ! -L "${binPath}/cosyses" ]]; then
  echo "Linking install script from: ${currentReleasePath}/install.sh to: ${binPath}/cosyses"
  ln -s "${currentReleasePath}/install.sh" "${binPath}/cosyses"
fi
