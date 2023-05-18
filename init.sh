#!/bin/bash -e

if [[ $(which install-package | wc -l) -eq 1 ]]; then
  echo "Using custom install function"
  customInstall=1
else
  echo "Using native install function"
  customInstall=0
fi

if [[ $(which git | wc -l) -eq 0 ]]; then
  if [[ "${customInstall}" == 1 ]]; then
    echo "Installing git"
    install-package git
  else
    echo "Installing git"
    UCF_FORCE_CONFOLD=1 DEBIAN_FRONTEND=noninteractive sudo apt-get install -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages git 2>&1
  fi
fi

echo "Determining latest hash"
gitHash=$(git ls-remote https://bitbucket.org/tofex/server.git)
if [[ -z "${gitHash}" ]]; then
  echo "Could not list remote hashes, try again in 3 seconds"
  sleep 3
  gitHash=$(git ls-remote https://bitbucket.org/tofex/server.git)
  if [[ -z "${gitHash}" ]]; then
    echo "Could not list remote hashes, try again in another 3 seconds"
    sleep 3
    gitHash=$(git ls-remote https://bitbucket.org/tofex/server.git)
    if [[ -z "${gitHash}" ]]; then
      echo "Could not list remote hashes, giving up"
      exit 1
    fi
  fi
fi
hash=$(echo "${gitHash}" | head -1 | sed "s/HEAD//" | head -c 12)
if [[ -z "${hash}" ]]; then
  echo "Could not determine latest hash"
  exit 1
fi
echo "Latest hash: ${hash}"
