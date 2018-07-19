#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds OpenSSL from sources.

# OpenSSH and a few other key programs can only use OpenSSL 1.0.2 at the moment
OPENSSL_DIR=openssl-1.0.2o
PKG_NAME=openssl

# Avoid shellcheck.net warning
CURR_DIR="$PWD"

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

# May be skipped if Perl is too old
SKIP_OPENSSL_TESTS=0

# Wget self tests
if ! perl -MTest::More -e1 2>/dev/null
then
    echo "OpenSSL requires Perl's Test::More. Skipping OpenSSL self tests."
    echo "To fix this issue, please install Test-More."
    SKIP_OPENSSL_TESTS=1
fi

# Wget self tests
if ! perl -MText::Template -e1 2>/dev/null
then
    echo "OpenSSL requires Perl's Text::Template. Skipping OpenSSL self tests."
    echo "To fix this issue, please install Text-Template."
    SKIP_OPENSSL_TESTS=1
fi

# OpenSSL and enable-ec_nistp_64_gcc_128 option
if [[ "$BUILD_BITS" -eq "32" ]]; then
    IS_X86_64=0;
fi

###############################################################################

echo
echo "********** OpenSSL **********"
echo

# Requires Git 1.7.10 or higher. May be a problem on older clients.
git clone git://github.com/openssl/openssl --branch OpenSSL_1_0_2-stable --single-branch "$OPENSSL_DIR"
cd "$OPENSSL_DIR"

CONFIG_FLAGS=("no-ssl2" "no-ssl3" "no-comp" "shared" "-DNDEBUG" "$SH_SYM" "$SH_OPT")

if [[ "$IS_X86_64" -eq "1" ]]; then
    CONFIG_FLAGS+=("enable-ec_nistp_64_gcc_128")
fi
if [[ "$IS_FREEBSD" -eq "1" ]]; then
    CONFIG_FLAGS+=("-Wno-error")
fi

if [[ ! -z "$SH_RPATH" ]]; then
    CONFIG_FLAGS+=("$SH_RPATH")
fi
if [[ ! -z "$SH_DTAGS" ]]; then
    CONFIG_FLAGS+=("$SH_DTAGS")
fi

# OpenSSL does not allow installing like Autotools and --libdir.
# The OpenSSL libdir must be below --prefix. As far as I know
# OpenSSL is the only software that has this requirement.
CONFIG_LIBDIR=$(basename "$INSTX_LIBDIR")
CONFIG_FLAGS+=("--prefix=$INSTX_PREFIX" "--libdir=$CONFIG_LIBDIR")

echo "Configuring OpenSSL with ${CONFIG_FLAGS[*]}"
echo "BUILD_BITS: $BUILD_BITS"

    KERNEL_BITS="$BUILD_BITS" \
./config ${CONFIG_FLAGS[*]}

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure OpenSSL"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ "$IS_DARWIN" -ne "0" ]]; then
    for mfile in $(find "$PWD" -name 'Makefile'); do
        sed -e 's|LD_LIBRARY_PATH|DYLD_LIBRARY_PATH|g' "$mfile" > "$mfile.fixed"
        mv "$mfile.fixed" "$mfile"
    done
fi

    MAKE_FLAGS=("-j" "$INSTX_JOBS" "depend")
    if [[ "$IS_BSD" -ne "0" ]]; then
        MAKE_FLAGS+=("MAKEDEPPROG=gcc -M")
    fi

    if ! "$MAKE" "INSTX_JOBS=$INSTX_JOBS" "${MAKE_FLAGS[@]}"
    then
        echo "Failed to update OpenSSL dependencies"
        [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
    fi
#fi

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build OpenSSL"
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

# Self tests are still unreliable, https://github.com/openssl/openssl/issues/4963
# TODO: tie self-tests to SKIP_OPENSSL_TESTS
# MAKE_FLAGS=("-j" "$INSTX_JOBS" test)
# if ! "$MAKE" "${MAKE_FLAGS[@]}"
# then
#     echo "Failed to test OpenSSL"
#     [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
# fi

MAKE_FLAGS=(install_sw)
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

    ARTIFACTS=("$OPENSSL_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-openssl.sh 2>&1 | tee build-openssl.log
    if [[ -e build-openssl.log ]]; then
        rm -f build-openssl.log
    fi
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
