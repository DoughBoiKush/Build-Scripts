#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds TinyXML from sources.

TXML2_TAR=6.2.0.tar.gz
TXML2_DIR=tinyxml2-6.2.0
PKG_NAME=tinyxml

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

DIGICERT_ROOT="$HOME/.cacert/digicert-root-ca.pem"
if [[ ! -f "$DIGICERT_ROOT" ]]; then
    echo "TinyXML requires several CA roots. Please run build-cacerts.sh."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ -e "$INSTX_CACHE/$PKG_NAME" ]]; then
    # Already installed, return success
    echo ""
    echo "$PKG_NAME is already installed."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
fi

# The password should die when this subshell goes out of scope
if [[ -z "$SUDO_PASSWORD" ]]; then
    source ./build-password.sh
fi

###############################################################################

echo
echo "********** TinyXML2 **********"
echo

# https://github.com/leethomason/tinyxml2/archive/6.0.0.tar.gz
"$WGET" --ca-certificate="$DIGICERT_ROOT" "https://github.com/leethomason/tinyxml2/archive/$TXML2_TAR" -O "$TXML2_TAR"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to download tinyxml2"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

rm -rf "$TXML2_DIR" &>/dev/null
gzip -d < "$TXML2_TAR" | tar xf -
cd "$TXML2_DIR"

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

MAKE_FLAGS=("-j" "$INSTX_JOBS")
MAKE_FLAGS+=("PKG_CONFIG_PATH=${BUILD_PKGCONFIG[*]}")
MAKE_FLAGS+=("CPPFLAGS=${BUILD_CPPFLAGS[*]}")
MAKE_FLAGS+=("CFLAGS=${BUILD_CFLAGS[*]}")
MAKE_FLAGS+=("CXXFLAGS=${BUILD_CXXFLAGS[*]}")
MAKE_FLAGS+=("LDFLAGS=${BUILD_LDFLAGS[*]}")
MAKE_FLAGS+=("LIBS=${BUILD_LIBS[*]}")

if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build tinyxml2"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

MAKE_FLAGS=("test")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
   echo "Failed to test tinyxml2"
   [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# TODO... fix this simple copy
echo "Installing TinyXML2"
if [[ ! (-z "$SUDO_PASSWORD") ]]; then
    echo "$SUDO_PASSWORD" | sudo -S cp tinyxml2.h "$INSTX_PREFIX/include"
    echo "$SUDO_PASSWORD" | sudo -S cp libtinyxml2.a "$INSTX_LIBDIR"
    echo ""
else
    cp tinyxml2.h "$INSTX_PREFIX/include"
    cp libtinyxml2.a "$INSTX_LIBDIR"
    echo ""
fi

cd "$CURR_DIR"

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_CACHE/$PKG_NAME"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$TXML2_TAR" "$TXML2_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-tinyxml2.sh 2>&1 | tee build-tinyxml2.log
    if [[ -e build-tinyxml2.log ]]; then
        rm -f build-tinyxml2.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
