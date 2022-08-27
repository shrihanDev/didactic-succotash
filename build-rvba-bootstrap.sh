#!/bin/bash
set -euo pipefail

log(){
  echo -e "\e[34m[**] $1\e[0m" >&2
}
mkdir logs

{
  log "Cloning termux-packages"
  git clone https://github.com/termux/termux-packages --depth=1 --no-tags
  cd termux-packages

  log "Checking out PR#10540"
  gh pr checkout 10540

  log "Changing package ID"
  sed -i 's/TERMUX_APP_PACKAGE="com.termux"/TERMUX_APP_PACKAGE="com.reisxd.rvba"/g' scripts/properties.sh

  log "Patching setup scripts"
  sed -i '/venv/d' scripts/setup-ubuntu.sh
  sed -i 's/openjdk-18/openjdk-17/g' scripts/setup-ubuntu.sh
  sed -i 's#cmdline-tools/bin#cmdline-tools/latest/bin#g' scripts/setup-android-sdk.sh

  log "Running setup scripts"
  ./scripts/setup-ubuntu.sh
  ./scripts/setup-android-sdk.sh

  log "Restoring the setup scripts"
  git reset HEAD scripts/setup-ubuntu.sh
  git reset HEAD scripts/setup-android-sdk.sh

 log "Patching build-bootstrap.sh"
 curl -sLo scripts/build-bootstraps.sh https://raw.githubusercontent.com/termux/termux-packages/f6fa7e932760e4edd67c155ca52ece3a8776d2c5/scripts/build-bootstraps.sh

  log "Building bootstrap for aarch64"
  ./scripts/run-docker.sh ./scripts/build-bootstraps.sh --add nodejs-lts,openjdk-17 --architectures aarch64

  log "Building bootstrap for arm"
  ./scripts/run-docker.sh ./scripts/build-bootstraps.sh --add nodejs-lts,openjdk-17 --architectures arm
} | tee -a logs/build-bootstrap.log

{
  clear

  log "Saving bootstrap zips"
  cp $(find -name bootstrap-*.zip -type f) ~

  log "Deleting bootstrap build cache"
  cd ..
  docker rm -vf $(docker ps -aq)

  log "Cloning termux-app"
  git clone --depth=1 --no-tags https://github.com/termux/termux-app

#  log "Patching setup scripts"
#  sed -i '/venv/d' termux-packages/scripts/setup-ubuntu.sh
#  sed -i 's/openjdk-18/openjdk-17/g' termux-packages/scripts/setup-ubuntu.sh
#  sed -i 's#cmdline-tools/bin#cmdline-tools/latest/bin#g' termux-packages/scripts/setup-android-sdk.sh

#  log "Running setup scripts"
#  ./termux-packages/scripts/setup-ubuntu.sh
#  ./termux-packages/scripts/setup-android-sdk.sh

#  log "Restoring the setup scripts"
#  git reset HEAD termux-packages/scripts/setup-ubuntu.sh
#  git reset HEAD termux-packages/scripts/setup-android-sdk.sh

  cd termux-app

  log "Changing package IDs"
  git grep -l 'com.termux' | xargs sed -i 's#com.termux#com.reisxd.rvba#g'
  git grep -l 'com_termux' | xargs sed -i 's#com_termux#com_reisxd_rvba#g'

  log "Patching downloadBootstrap()"
  sed -i '#def downloadBootstrap#a return;' app/build.gradle

  log "Copying aarch64 bootstrap"
  cp ~/bootstrap-aarch64.zip app/src/main/cpp

  log "Patching termux-bootstrap-zip.S"
  cat <<EOF >app/src/main/cpp/termux-bootstrap-zip.S
asm
     .global blob
     .global blob_size
     .section .rodata
 blob:
 #if defined __i686__

 #elif defined __x86_64__

 #elif defined __aarch64__
     .incbin "bootstrap-aarch64.zip"
 #elif defined __arm__

 #else
 # error Unsupported arch
 #endif
 1:
 blob_size:
     .int 1b - blob
EOF
  
  log "Patching app/build.gradle"
  sed "s#include 'x86', 'x86_64', 'armeabi-v7a', 'arm64-v8a'#include 'arm64-v8a'#g" app/build.gradle

  log "Patching terminal-emulator/build.gradle"
  sed "s#abiFilters 'x86', 'x86_64', 'armeabi-v7a', 'arm64-v8a'#abiFilters 'arm64-v8a'#g"

  log "Building app for aarch64"
  ./gradlew -a --daemon --parallel --build-cache --configuration-cache build

  log "Copying arm bootstrap"
  rm app/src/main/cpp/bootstrap-aarch64.zip
  cp ~/bootstrap-arm.zip app/src/main/cpp

  log "Patching termux-bootstrap-zip.S"
  cat <<EOF >app/src/main/cpp/termux-bootstrap-zip.S
asm
     .global blob
     .global blob_size
     .section .rodata
 blob:
 #if defined __i686__

 #elif defined __x86_64__

 #elif defined __aarch64__

 #elif defined __arm__
     .incbin "bootstrap-arm.zip"

 #else
 # error Unsupported arch
 #endif
 1:
 blob_size:
     .int 1b - blob
EOF
  
  log "Patching app/build.gradle"
  sed "s#include 'arm64-v8a'#include 'armeabi-v7a'#g" app/build.gradle

  log "Patching terminal-emulator/build.gradle"
  sed "s#abiFilters 'arm64-v8a'#abiFilters 'armeabi-v7a'#g" terminal-emulator/build.gradle

  log "Building app for arm"
  ./gradlew -a --daemon --parallel --build-cache --configuration-cache build
} | tee -a logs/build-app.log
