#!/usr/bin/env bash

serial=e2a9f08d

# Fail on error, verbose output
set -exo pipefail

# Build project
ndk-build NDK_DEBUG=1 1>&2

# Figure out which ABI and SDK the device has
abi=$(adb -s $serial shell getprop ro.product.cpu.abi | tr -d '\r')
sdk=$(adb -s $serial shell getprop ro.build.version.sdk | tr -d '\r')
pre=$(adb -s $serial shell getprop ro.build.version.preview_sdk | tr -d '\r')
rel=$(adb -s $serial shell getprop ro.build.version.release | tr -d '\r')

if [[ -z "$pre" ]]; then
  sdk=$(($sdk + 1))
fi

# PIE is only supported since SDK 16
if (($sdk >= 16)); then
  bin=minicap
else
  bin=minicap-nopie
fi

args=
if [ "$1" = "autosize" ]; then
  set +o pipefail
  size=$(adb -s $serial shell dumpsys window | grep -Eo 'init=\d+x\d+' | head -1 | cut -d= -f 2)
  if [ "$size" = "" ]; then
    w=$(adb -s $serial shell dumpsys window | grep -Eo 'DisplayWidth=\d+' | head -1 | cut -d= -f 2)
    h=$(adb -s $serial shell dumpsys window | grep -Eo 'DisplayHeight=\d+' | head -1 | cut -d= -f 2)
    size="${w}x${h}"
  fi
  args="-P $size@$size/0"
  set -o pipefail
  shift
fi

# Create a directory for our resources
dir=/data/local/tmp/minicap-devel
# Keep compatible with older devices that don't have `mkdir -p`.
adb -s $serial shell "mkdir $dir 2>/dev/null || true"

# Upload the binary
adb -s $serial push libs/$abi/$bin $dir

# Upload the shared library
if [ -e jni/minicap-shared/aosp/libs/android-$rel/$abi/minicap.so ]; then
  adb -s $serial push jni/minicap-shared/aosp/libs/android-$rel/$abi/minicap.so $dir
else
  adb -s $serial push jni/minicap-shared/aosp/libs/android-$sdk/$abi/minicap.so $dir
fi

# Run!
adb -s $serial shell LD_LIBRARY_PATH=$dir $dir/$bin $args "$@"

# Clean up
adb -s $serial shell rm -r $dir
