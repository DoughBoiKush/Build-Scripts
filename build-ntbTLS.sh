#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds ntbtls from sources.

NTBTLS_TAR=ntbtls-0.1.2.tar.bz2
NTBTLS_DIR=ntbtls-0.1.2
PKG_NAME=ntbtls

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
echo "********** ntbtls **********"
echo

"$WGET" --ca-certificate="$LETS_ENCRYPT_ROOT" "https://gnupg.org/ftp/gcrypt/ntbtls/$NTBTLS_TAR" -O "$NTBTLS_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download ntbtls"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$NTBTLS_DIR" &>/dev/null
tar xjf "$NTBTLS_TAR"
cd "$NTBTLS_DIR"

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure --enable-shared --prefix="$INSTX_PREFIX" --libdir="$INSTX_LIBDIR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure ntbtls"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build ntbtls"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("check" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test ntbtls"
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

    ARTIFACTS=("$NTBTLS_TAR" "$NTBTLS_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-ntbtls.sh 2>&1 | tee build-ntbtls.log
    if [[ -e build-ntbtls.log ]]; then
        rm -f build-ntbtls.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
