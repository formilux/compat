#!/bin/bash


function usage() {
    echo "Usage: ${0##*/} [options] [PKG ...]" >&2
    echo "Options:" >&2
    sed -n -r -e 's/^\s*##([^:]+): /  \1\t/p' < $0 >&2
    echo >&2
    exit 1
}

function die() {
    echo "Fatal: $*" >&2
    exit 2
}

function onError() {
    RET=$?
    echo "Error stack:" >&2
    for i in ${!FUNCNAME[*]} ; do
        printf "  %-15s %s\n" "${BASH_SOURCE[$i]}:${BASH_LINENO[$i]}" \
                              "${FUNCNAME[$i]}(...)"
    done >&2
    return $?
}

function onExit() {
    RET=$?
    exit $?
}

ALL_NEED=(
    bash-4 depmod flx make-3.81 make-3.82 make mksquashfs-2
	mksquashfs-3 mksquashfs-4 sudo
)
# NEED=( */build.sh )
# NEED=( */ )
# NEED=( ${SUBS[@]%/*} )


set -e
trap onExit EXIT
trap onError ERR

while [[ $# != 0 ]] ; do
    if [[ $1 == -h || $1 == --help ]] ; then
        ## -h, --help   : this help
        usage
    elif [[ $1 == --dist ]] ; then
        ## --dist DISTRO: distro name (ex: centos5)
        DIST=$2 ; shift
    elif [[ $1 == --from ]] ; then
        ## --from FILENAME: file containing packages to build
        if [[ -r $2 ]] ; then
            NEED=( $(<$2) ) ; shift
        else
            die "Can't read needed file $2"
        fi
    elif [[ $1 == --install ]] ; then
        ## --install DESTDIR: install to this directory
        if [[ -d $2 ]] ; then
            DESTDIR=$2 ; shift
        else
            die "Missing or invalid destination directory (ex: /opt/flx2/bin)"
        fi
    elif [[ ${1:0:1} == - ]] ; then
        die "Unknown parameter $1"
    else
        NEED=( ${NEED[@]} $1 )
    fi
    shift
done

if [[ ${#NEED[@]} == 0 ]] ; then
    NEED=( ${ALL_NEED[@]} )
fi

# look for distrib known packages
if [[ -z $DIST || ! -e dist/$DIST ]] ; then
    HAVE=( )
else
    HAVE=( $(<dist/$DIST) )
fi

[[ ! -d build ]] && mkdir build

HAVE_=" ${HAVE[*]} "
for need in ${NEED[@]} ; do
    [[ -z "${HAVE_##* $need *}" ]] && continue
    [[ -x scripts/build-$need ]] ||
        die "don't known how to build $need: can't read scripts/build-$need"
    ( cd build ; BUILDDIR=$need ; source ../scripts/build-$need )
done

