#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds ICU from sources.

# ICU 60.2
ICU_TAR=icu4c-60_2-src.tgz
ICU_DIR=icu
PKG_NAME=icu

###############################################################################

CURR_DIR=$(pwd)
function finish {
  cd "$CURR_DIR"
}
trap finish EXIT

# Sets the number of make jobs if not set in environment
: "${INSTX_JOBS:=4}"

###############################################################################

# Get the environment as needed. We can't export it because it includes arrays.
if ! source ./build-environ.sh
then
    echo "Failed to set environment"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ -e "$INSTX_CACHE/$PKG_NAME" ]]; then
    # Already installed, return success
    echo ""
    echo "$PKG_NAME is already installed."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
fi

# Get a sudo password as needed. The password should die when this
# subshell goes out of scope.
if [[ -z "$SUDO_PASSWORD" ]]; then
    source ./build-password.sh
fi

###############################################################################

echo
echo "********** libicu **********"
echo

# http://download.icu-project.org/files/icu4c/60.2/icu4c-60_2-src.tgz
"$WGET" "http://download.icu-project.org/files/icu4c/60.2/$ICU_TAR" -O "$ICU_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download libicu"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$ICU_DIR" &>/dev/null
gzip -d < "$ICU_TAR" | tar xf -
cd "$ICU_DIR/source"

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure --enable-shared --enable-static \
    --prefix="$INSTX_PREFIX" --libdir="$INSTX_LIBDIR" \
    --with-library-bits="$INSTX_BITNESS" \
    --with-data-packaging=auto

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure libicu"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build libicu"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

 MAKE_FLAGS=("check")
 if ! "$MAKE" "${MAKE_FLAGS[@]}"
 then
    echo "Failed to test libicu"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
 fi

MAKE_FLAGS=("install")
if [[ ! (-z "$SUDO_PASSWORD") ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_CACHE/$PKG_NAME"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$ICU_TAR" "$ICU_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-icu.sh 2>&1 | tee build-icu.log
    if [[ -e build-icu.log ]]; then
        rm -f build-icu.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
