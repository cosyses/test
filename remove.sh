#!/bin/bash -e

distribution=$(awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"')

if [[ "${distribution}" == "Ubuntu" ]]; then
  basePath="/usr/local"
  binPath="${basePath}/bin"
  libPath="${basePath}/lib"
  cosysesPath="${libPath}/cosyses"
else
  >&2 echo "Unsupported OS: ${distribution}"
  exit 1
fi

rm -rf "${binPath}/cosyses"
rm -rf "${cosysesPath}"
