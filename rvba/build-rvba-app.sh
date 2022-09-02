#!/bin/bash
set -euo pipefail

log(){
  echo -e "\e[34m[**] $1\e[0m" >&2
}

log "Cloning termux-app"
git clone --depth=1 --no-tags https://github.com/termux/termux-app

log "Cloning termux-packages"
git clone --depth=1 --no-tags https://github.com/termux/termux-packages

log "Patching setup scripts"
sed -i 's/TERMUX_APP_PACKAGE="com.termux"/TERMUX_APP_PACKAGE="com.reisxd.rvba"/g' termux-packages/scripts/properties.sh
sed -i '/venv/d' termux-packages/scripts/setup-ubuntu.sh
sed -i 's/openjdk-18/openjdk-17/g' termux-packages/scripts/setup-ubuntu.sh
sed -i 's#cmdline-tools/bin#cmdline-tools/latest/bin#g' termux-packages/scripts/setup-android-sdk.sh

log "Running setup scripts"
./termux-packages/scripts/setup-ubuntu.sh
./termux-packages/scripts/setup-android-sdk.sh

log "Deleting termux-packages"
rm -rf termux-packages

cd termux-app

log "Changing package IDs"
git grep -l 'com\.termux' | xargs sed -i 's#com\.termux#com\.reisxdw\.rvba#g'
(git grep -l 'com_termux' | xargs sed -i 's#com_termux#com_reisxd_rvba#g') || true
sed -i 's#implementation "com\.reisxd\.rvba:termux-am-library:v2\.0\.0"#implementation "com\.termux:termux-am-library:v2\.0\.0"#g' termux-shared/build.gradle

log "Patching downloadBootstrap()"
sed -i '#def downloadBootstrap#a return;' app/build.gradle

if [[ -z $1 ]] || [[ $1 == aarch64 ]]; then

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
  sed -i "s#include 'x86', 'x86_64', 'armeabi-v7a', 'arm64-v8a'#include 'arm64-v8a'#g" app/build.gradle

  log "Patching terminal-emulator/build.gradle"
  sed -i "s#abiFilters 'x86', 'x86_64', 'armeabi-v7a', 'arm64-v8a'#abiFilters 'arm64-v8a'#g" terminal-emulator/build.gradle

  log "Building app for aarch64"
  ./gradlew -a --daemon --parallel --build-cache --configuration-cache assembleDebug

elif [[ $1 == arm ]]; then

  log "Copying arm bootstrap"
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
  sed -i "s#include 'x86', 'x86_64', 'armeabi-v7a', 'arm64-v8a'#include 'armeabi-v7a'#g" app/build.gradle

  log "Patching terminal-emulator/build.gradle"
  sed -i "s#abiFilters 'x86', 'x86_64', 'armeabi-v7a', 'arm64-v8a'#abiFilters 'armeabi-v7a'#g" terminal-emulator/build.gradle

  log "Building app for arm"
  ./gradlew -a --daemon --parallel --build-cache --configuration-cache assembleDebug

else
  log "Invalid arch: $1"
  exit 128
fi
