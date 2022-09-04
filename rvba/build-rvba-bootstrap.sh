#!/bin/bash
set -euo pipefail

log(){
  [[ "$2" != n ]] && ( echo "::group::$1"; return 0; )
  echo -e "\e[34m[***] $1\e[0m" >&2
}
end_group(){
  echo "::endgroup::"
}

log "Cloning termux-packages" y
git clone https://github.com/termux/termux-packages --depth=1 --no-tags
cd termux-packages
end_group

# log "Changing package ID" y
# sed -i 's/TERMUX_APP_PACKAGE="com.termux"/TERMUX_APP_PACKAGE="com.reisxd.rvba"/g' scripts/properties.sh
# end_group

log "Patching generate script" y
PKGS_TO_REMOVE='${TERMUX_PACKAGE_MANAGER} bzip2 command-not-found proot diffutils findutils gawk grep less procps psmisc sed tar termux-keyring util-linux xz-utils ed debianutils dos2unix inetutils lsof net-tools patch'
for pkg in $PKGS_TO_REMOVE; do
  sed -i "s@pull_package $pkg@echo \"$pkg, take a huge L\"@g" ./scripts/generate-bootstraps.sh
done
end_group

if [[ $1 == aarch64 ]] || [[ -z $1 ]]; then
  log "Building bootstrap for aarch64" y
  ./scripts/run-docker.sh ./scripts/generate-bootstraps.sh --architectures aarch64 --add nodejs-lts,openjdk-17
  unzip -l bootstrap-aarch64.zip | grep SYMLINKS.txt
  end_group
elif [[ $1 == arm ]]; then
  log "Building bootstrap for arm" y
  ./scripts/run-docker.sh ./scripts/generate-bootstraps.sh --architectures arm --add nodejs-lts,openjdk-17
  unzip -l bootstrap-arm.zip | grep SYMLINKS.txt
  end_group
else
  log "Invalid arch: $1" n
  exit 127
fi
