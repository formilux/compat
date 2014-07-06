#!/bin/bash


usage() {
    echo "Usage: ${0##*/} [options] [PKG ...]" >&2
    echo "Options:" >&2
    sed -n -r -e 's/^\s*##([^:]+): /  \1\t/p' < $0 >&2
    echo >&2
    exit 1
}

die() {
    echo "Fatal: $*" >&2
    exit 2
}

onError() {
    RET=$?
    echo "Error stack:" >&2
    for i in ${!FUNCNAME[*]} ; do
        printf "  %-15s %s\n" "${BASH_SOURCE[$i]}:${BASH_LINENO[$i]}" \
                              "${FUNCNAME[$i]}(...)"
    done >&2
    return $?
}

onExit() {
    RET=$?
    exit $?
}


do_prepare() {
    if [[ ! -e ../$SRC_FILENAME ]] ; then
        echo "## downloading $SRC_FETCH_PATH" >&2

        if ! "$CDIR/scripts/get_cached_file" "$SRC_FETCH_PATH" "../$SRC_FILENAME" "$FLX_SRC_CACHE_DIRS" ; then
            die "can't read or download $SRC_FILENAME. You may want to force \$FLX_SRC_CACHE_DIRS to your source cache location."
        fi
    fi

    echo "## extracting $SRC_FILENAME in $BUILDDIR" >&2
    case "$SRC_FILENAME" in
      *.tar.gz|*.tgz)          tar --strip-components 1 -zxf ../$SRC_FILENAME ;;
      *.tar.bz2|*.tbz2|*.tbz)  tar --strip-components 1 -zxf ../$SRC_FILENAME ;;
      *)                       tar --strip-components 1  -xf ../$SRC_FILENAME ;;
    esac || die "source file $SRC_FILENAME seems corrupted."

    for patch in ${PATCHES[@]} ; do
        echo "## patching with $PDIR/$PKG/$patch" >&2
        patch -p${PATCH_LEVEL:-1} < $PDIR/$PKG/$patch
    done
}

ALL_NEED=( 
    make-3.81 make-3.82 bash-4
    depmod depmod flx liblzma-5 mksquashfs-2 mksquashfs-3 mksquashfs-4 sudo
)
# NEED=( */build.sh )
# NEED=( */ )
# NEED=( ${SUBS[@]%/*} )

CPU=$(grep -cw ^processor /proc/cpuinfo)
MAKE=${MAKE:-make}
PMAKE="$MAKE -j$CPU"

CDIR=$(readlink -f ${BASH_SOURCE[0]})
CDIR=${CDIR%/*}
PDIR="$CDIR/patches"

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
    elif [[ $1 == --reuse ]] ; then
        ## --reuse      : do not clean before running (useful with --install)
        REUSE=1
    elif [[ $1 == --clean ]] ; then
        rm -rf "$CDIR/build"
        exit 0
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

[[ ! -d $CDIR/build ]] && mkdir $CDIR/build

HAVE_=" ${HAVE[*]} "
for PKG in ${NEED[@]} ; do
    [[ -z "${HAVE_##* $PKG *}" ]] && continue
    [[ -x packages/$PKG ]] ||
        die "don't known how to build $PKG: can't read packages/$PKG"
    (
        echo "## building $PKG ..." >&2
        BUILDDIR=$CDIR/build/$PKG

        if [ -z "$REUSE" ]; then
            rm -rf $BUILDDIR
            mkdir -p $BUILDDIR
            source $CDIR/packages/$PKG
            cd $BUILDDIR
            do_prepare
            do_compile
        else
            source $CDIR/packages/$PKG
            cd $BUILDDIR
        fi

        if [[ -d $DESTDIR ]] ; then
            echo "## installing to $DESTDIR" >&2
            do_install
        else
            echo "re-run with --install to install binaries" >&2
        fi
    ) || exit $?
done
