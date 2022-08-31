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

  log "Patching build script"
  curl -sLo scripts/build-bootstraps.sh https://github.com/termux/termux-packages/raw/f6fa7e932760e4edd67c155ca52ece3a8776d2c5/scripts/build-bootstraps.sh

  log "Building bootstrap for aarch64"
  ./scripts/run-docker.sh ./scripts/build-bootstraps.sh --add nodejs-lts,openjdk-17 --architectures aarch64

  log "Building bootstrap for arm"
  ./scripts/run-docker.sh ./scripts/build-bootstraps.sh --add nodejs-lts,openjdk-17 --architectures arm
} | tee -a logs/build-bootstrap.log

