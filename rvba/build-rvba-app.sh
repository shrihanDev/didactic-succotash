#!/bin/bash
set -euo pipefail

log(){
  [[ "$2" != n ]] && ( echo "::group::$1"; return 0; )
  echo -e "\e[34m[***] $1\e[0m" >&2
}

end_group(){
  echo "::endgroup::"
}

log "Cloning termux-app" y
git clone --depth=1 --no-tags https://github.com/termux/termux-app
end_group

log "Cloning termux-packages" y
git clone --depth=1 --no-tags https://github.com/termux/termux-packages
end_group

log "Patching setup scripts" y
#sed -i 's/TERMUX_APP_PACKAGE="com.termux"/TERMUX_APP_PACKAGE="com.reisxd.rvba"/g' termux-packages/scripts/properties.sh
sed -i '/venv/d' termux-packages/scripts/setup-ubuntu.sh
sed -i 's/openjdk-18/openjdk-17/g' termux-packages/scripts/setup-ubuntu.sh
sed -i 's#cmdline-tools/bin#cmdline-tools/latest/bin#g' termux-packages/scripts/setup-android-sdk.sh
end_group

log "Running setup scripts" y
./termux-packages/scripts/setup-ubuntu.sh
./termux-packages/scripts/setup-android-sdk.sh
end_group

log "Deleting termux-packages" y
rm -rf termux-packages
end_group

cd termux-app

# log "Changing package IDs" y
# git grep -l 'com\.termux' | xargs sed -i 's#com\.termux#com\.reisxd\.rvba#g'
# (git grep -l 'com_termux' | xargs sed -i 's#com_termux#com_reisxd_rvba#g') || true
# sed -i 's#implementation "com\.reisxd\.rvba:termux-am-library:v2\.0\.0"#implementation "com\.termux:termux-am-library:v2\.0\.0"#g' termux-shared/build.gradle
# end_group

log "Patching downloadBootstrap()" y
sed -i '/def downloadBootstrap/a return;' app/build.gradle
end_group

log "Setting up variables" y
RELEASE_VERSION_NAME="$GITHUB_REF_NAME+${GITHUB_SHA:0:7}"
APK_DIR_PATH="./app/build/outputs/apk/debug"
APK_VERSION_TAG="$RELEASE_VERSION_NAME-$1"
APK_BASENAME_PREFIX="revanced-builder_$APK_VERSION_TAG"
echo "APK_DIR_PATH=$APK_DIR_PATH" >> $GITHUB_ENV
echo "APK_VERSION_TAG=$APK_VERSION_TAG" >> $GITHUB_ENV
echo "APK_BASENAME_PREFIX=$APK_BASENAME_PREFIX" >> $GITHUB_ENV
export TERMUX_APP_VERSION_NAME="${RELEASE_VERSION_NAME/v/}" 
export TERMUX_APK_VERSION_TAG="$APK_VERSION_TAG"
export TERMUX_PACKAGE_VARIANT="apt-android-7"
end_group

if [[ -z $1 ]] || [[ $1 == aarch64 ]]; then

  log "Copying aarch64 bootstrap" y
  cp ~/bootstrap-aarch64.zip app/src/main/cpp
  end_group

  log "Patching termux-bootstrap-zip.S" y
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
  end_group

  log "Patching app/build.gradle" y
  sed -i "s#include 'x86', 'x86_64', 'armeabi-v7a', 'arm64-v8a'#include 'arm64-v8a'#g" app/build.gradle
  end_group

  log "Patching terminal-emulator/build.gradle" y
  sed -i "s#abiFilters 'x86', 'x86_64', 'armeabi-v7a', 'arm64-v8a'#abiFilters 'arm64-v8a'#g" terminal-emulator/build.gradle
  end_group

  log "Building app for aarch64" y
  ./gradlew -a --daemon --parallel --build-cache --configuration-cache assembleDebug
  end_group

elif [[ $1 == arm ]]; then

  log "Copying arm bootstrap" y
  cp ~/bootstrap-arm.zip app/src/main/cpp
  end_group

  log "Patching termux-bootstrap-zip.S" y
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
  end_group

  log "Patching app/build.gradle" y
  sed -i "s#include 'x86', 'x86_64', 'armeabi-v7a', 'arm64-v8a'#include 'armeabi-v7a'#g" app/build.gradle
  end_group

  log "Patching terminal-emulator/build.gradle" y
  sed -i "s#abiFilters 'x86', 'x86_64', 'armeabi-v7a', 'arm64-v8a'#abiFilters 'armeabi-v7a'#g" terminal-emulator/build.gradle
  end_group

  log "Building app for arm" y
  ./gradlew -a --daemon --parallel --build-cache --configuration-cache assembleDebug
  end_group

else
  log "Invalid arch: $1" n
  exit 128
fi
