#!/bin/bash
set -euo pipefail

log(){
  echo -e "\e[34m[**] $1\e[0m" >&2
}

{
  log "Cloning termux-packages"
  git clone https://github.com/termux/termux-packages --depth=1 --no-tags
  cd termux-packages

  log "Changing package ID"
  sed -i 's/TERMUX_APP_PACKAGE="com.termux"/TERMUX_APP_PACKAGE="com.reisxd.rvba"/g' scripts/properties.sh

  #log "Patching setup scripts"
  #sed -i '/venv/d' scripts/setup-ubuntu.sh
  #sed -i 's/openjdk-18/openjdk-17/g' scripts/setup-ubuntu.sh
  #sed -i 's#cmdline-tools/bin#cmdline-tools/latest/bin#g' scripts/setup-android-sdk.sh

  #log "Running setup scripts"
  #./scripts/setup-ubuntu.sh
  #./scripts/setup-android-sdk.sh

  log "Patching generate script"
  curl -sLo scripts/generate-bootstraps.sh https://github.com/termux/termux-packages/raw/60a48180ed2e316404e1913fd8b6f382520cb333/scripts/generate-bootstraps.sh
  PKGS_TO_REMOVE='${TERMUX_PACKAGE_MANAGER} bzip2 command-not-found proot diffutils findutils gawk grep less procps psmisc sed tar termux-keyring util-linux xz-utils'
  for pkg in $PKGS_TO_REMOVE; do
    sed -i "s@pull_package $pkg@# $pkg, take a huge L@g" ./scripts/generate-bootstraps.sh
  done

  log "Building packages for aarch64"
  ./scripts/run-docker.sh ./build-package.sh -a aarch64 bash coreutils dash termux-exec termux-tools nano unzip nodejs-lts openjdk-17

  log "Building packages for arm"
  ./scripts/run-docker.sh ./build-package.sh -a arm bash coreutils dash termux-exec termux-tools nano unzip nodejs-lts openjdk-17

  log "Building bootstrap for aarch64"
  ./scripts/run-docker.sh ./scripts/generate-bootstraps.sh --architectures aarch64 -c -i bash,dash,coreutils,nano,unzip,nodejs-lts,openjdk-17

  log "Building bootstrap for arm"
  ./scripts/run-docker.sh ./scripts/generate-bootstraps.sh --architectures arm -c -i bash,dash,coreutils,nano,unzip,nodejs-lts,openjdk-17
} | tee -a logs/build-bootstrap.log

