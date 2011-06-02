#!/bin/bash -e
#
# Copyright (c) 2011, Cloudera, inc.
# All rights reserved.

set -e

# Set no-check-certificate since github's SSL certs
# are currently messed up as of early 2011
WGET_OPTS=${WGET_OPTS:---no-check-certificate}

REQ_ANT_VERSION=1.7.0 # minimum version required
ANT_VERSION="1.8.2"   # ant version that will auto-download if -a is passed
ANT_TARBALL="apache-ant-${ANT_VERSION}-bin.tar.gz"
ANT_TARBALL_URL="http://www.gtlib.gatech.edu/pub/apache/ant/binaries/${ANT_TARBALL}"

display_help() {
    echo "usage: $0 [-h][-D][-R][-a][-u <name>][-e <addr>][-H <host>][-r <release>]"
    echo -e "
  Options:

    -h|--help               display help text
    -a|--ant                automatically download ant within the build tree

    Infrequently used:

    -r|--release <release>  release name or number (appended to the package version)
                            (default: 1)
    -u|--user <name>        username of the person creating the package
                            (default: ${USER})
    -e|--packager-email <addr>
                            email address of packager
                            (default: ${USER}@$(hostname -f))
    -H|--host               host on which the package was built
                            (default: $(hostname -f))
    -D|--no-deb             do not build debian packages, even if debuild is found
    -R|--no-rpm             do not build rpm packages, even if rpmbuild is found
    -d|--debug              enable debug mode (set -x)
"
}

# error()
#
# Display an error message and optionally exit if an exit code is provided.
#
# error "Something bad happened"
# error "Command foo not found" 1
error() {
    message="$1"
    shift

    echo "Error: ${message}"

    exit_code="$1"
    shift

    if [ -n "${exit_code}" ] ; then
        exit "${exit_code}"
    fi
}

while [ -n "$*" ] ; do

    arg="$1"
    shift

    case "${arg}" in
        -h|-\?|--help)
            _opt_display_help=1
            ;;
        -D|--no-deb)
            SKIP_DEB=1
            ;;
        -R|--no-rpm)
            SKIP_RPM=1
            ;;
        -n|--name)
            NAME="$1"
            shift
            ;;
        -u|--user)
            PACKAGER="$1"
            shift
            ;;
        -e|--packager-email)
            PACKAGER_EMAIL="$1"
            shift
            ;;
        -H|--host)
            HOST="$1"
            shift
            ;;
        -r|--release)
            RELEASE="$1"
            shift
            ;;
        -a|--ant)
            _opt_handle_ant=1
            ;;
        -d|--debug)
            set -x
            ;;
        *)
            error "Unknown argument ${arg}"
            ;;
    esac
done

if [ -n "${_opt_display_help}" ] ; then
    display_help
    exit
fi

##############################
# Begin configurables
##############################
RELEASE=${RELEASE:-1}

# Some metadata fields for the packages (used only by rpms)
PACKAGER=${PACKAGER:-$(getent passwd $USER | cut -d':' -f5 | cut -d, -f1)}
HOST=${HOST:-$(hostname -f)}
PACKAGER_EMAIL=${PACKAGER_EMAIL:-$USER@$HOST}

# The hadoop home that the packages will eventually install into
# TODO(todd) this is currently only used by rpms, I believe
HADOOP_HOME=${HADOOP_HOME:-/usr/lib/hadoop-0.20}
##############################
# End configurables
##############################
BINDIR=$(readlink -f $(dirname $0))
mkdir -p build

download_tarball_from_github() {
    GITHUB_ACCOUNT=${GITHUB_ACCOUNT:-cloudera}
    GITHUB_BRANCH=${GITHUB_BRANCH:-master}
    PACKAGE_HOMEPAGE=http://github.com/$GITHUB_ACCOUNT/hadoop-lzo
    TARURL=http://github.com/$GITHUB_ACCOUNT/hadoop-lzo/tarball/$GITHUB_BRANCH
    DST_TAR=$BINDIR/build/src.tar.gz
    if [ ! -s $DST_TAR ]; then
        echo Source does not appear to have been downloaded yet.
        echo Downloading from $TARURL to ${DST_TAR}...
        wget $WGET_OPTS -O $DST_TAR $TARURL
    else
        echo Using cached source in $DST_TAR
    fi
    DIR_IN_TAR=$(tar tzf $DST_TAR 2>/dev/null | head -1)
    GIT_HASH=$(expr match $DIR_IN_TAR ".*hadoop-lzo-\(.*\)/")
    GIT_HASH=${GIT_HASH//-/.} # RPM does not support dashes in version numbers
    echo "Git hash: $GIT_HASH"
    NAME=${NAME:-$GITHUB_ACCOUNT-hadoop-lzo}
    VERSION=$(date +"%Y%m%d%H%M%S").$GIT_HASH

    echo Retarring as $NAME-$VERSION
    pushd $BINDIR/build/ > /dev/null
    OUTDIR=$NAME-$VERSION
    mkdir $OUTDIR
    tar -C $OUTDIR/ --strip-components=1 -xzf $DST_TAR
    tar czf $NAME-$VERSION.tar.gz $OUTDIR/
    popd > /dev/null

    CHECKOUT_TAR=$BINDIR/build/$NAME-$VERSION.tar.gz
    echo Prepared source tarball at $CHECKOUT_TAR
}

setup_ant() {
    echo Downloading and setting up ant...

    if [ ! -d ${BINDIR}/build/apache-ant-${ANT_VERSION} ] ; then
        echo Downloading ant from $ANT_TARBALL_URL
        wget $WGET_OPTS -P "${BINDIR}/build" "${ANT_TARBALL_URL}"
        tar -C "${BINDIR}/build" -zxf "${BINDIR}/build/apache-ant-${ANT_VERSION}-bin.tar.gz"
    else
        echo Using cached copy of ant in build/ directory
    fi

    ANT_HOME="${BINDIR}/build/apache-ant-${ANT_VERSION}"
    PATH="${ANT_HOME}/bin:${PATH}"

    export PATH ANT_HOME
    echo ant setup complete.
}

do_substs() {
sed "
 s,@PACKAGE_NAME@,$NAME,g;
 s,@PACKAGE_HOMEPAGE@,$PACKAGE_HOMEPAGE,g;
 s,@VERSION@,$VERSION,g;
 s,@RELEASE@,$RELEASE,g;
 s,@PACKAGER@,$PACKAGER,g;
 s,@PACKAGER_EMAIL@,$PACKAGER_EMAIL,g;
 s,@HADOOP_HOME@,$HADOOP_HOME,g;
"
}

####
# Check basic build deps
####
if [ -z "$SKIP_RPM" ] && ! which rpmbuild > /dev/null ; then
  echo rpmbuild does not appear to be installed. Skipping RPM build.
  SKIP_RPM=1
fi

if [ -z "$SKIP_DEB" ] && ! which debuild > /dev/null ; then
  echo debuild does not appear to be installed. Skipping debian package build.
  SKIP_DEB=1
fi

echo Checking for gcc...
if ! which gcc > /dev/null ; then
  echo gcc not found. Please install development packages for your platform.
  exit 1
fi

echo Checking for lzo libraries...
if ! echo 'int main() {}' | gcc -llzo2 -x c -o /dev/null - > /dev/null ; then
  echo liblzo2.so not found. Please install lzo development libraries for
  echo your platform.
  exit 1
fi

if [ -z "$_opt_handle_ant" ]; then
  echo Checking for ant...
  if ! which ant > /dev/null ; then
    echo ant not found on \$PATH. Consider passing the --ant flag to
    echo automatically download and use the necessary version of ant.
    exit 1
  else
    echo -n Checking ant version...
    ANT_VERSION_OUT=$(ant -version)
    ANT_VERSION=$(expr match "$ANT_VERSION_OUT" ".*version \([0-9]*.[0-9]*.[0-9]*\)")
    echo $ANT_VERSION
    if [ $(printf "$REQ_ANT_VERSION\n$ANT_VERSION\n" | sort -n | head -1) != $REQ_ANT_VERSION ]; then
      echo Current version of ant \($ANT_VERSION\) is too low. Consider using the --ant flag.
      exit 1
    fi
  fi
fi

if [ -n "${_opt_handle_ant}" ] ; then
    setup_ant
fi

download_tarball_from_github
CHECKOUT=$BINDIR/${NAME}-$VERSION


if [ ! -e $CHECKOUT_TAR ]; then
  pushd $CHECKOUT
  cd ..
  tar czf $CHECKOUT_TAR $(basename $CHECKOUT)
  popd
fi

##############################
# RPM
##############################
TOPDIR=$BINDIR/build/topdir
if [ -z "$SKIP_RPM" ]; then
rm -Rf $TOPDIR
mkdir -p $TOPDIR

(cd $TOPDIR/ && mkdir SOURCES BUILD SPECS SRPMS RPMS BUILDROOT)

cat $BINDIR/template.spec | do_substs > $TOPDIR/SPECS/${NAME}.spec

cp $CHECKOUT_TAR $TOPDIR/SOURCES

pushd $TOPDIR/SPECS > /dev/null
rpmbuild $RPMBUILD_FLAGS \
  --buildroot $(pwd)/../BUILDROOT \
  --define "_topdir $(pwd)/.." \
  -ba ${NAME}.spec
popd
fi

##############################
# Deb
##############################
if [ -z "$SKIP_DEB" ]; then
DEB_DIR=$BINDIR/build/deb
mkdir -p $DEB_DIR
rm -Rf $DEB_DIR

mkdir $DEB_DIR
cp -a $CHECKOUT_TAR $DEB_DIR/${NAME}_$VERSION.orig.tar.gz
pushd $DEB_DIR
tar xzf *.tar.gz
cp -a $BINDIR/debian/ ${NAME}-$VERSION/debian
for f in $(find ${NAME}-$VERSION/debian -type f) ; do
  do_substs < $f > /tmp/$$.tmp && chmod --reference=$f /tmp/$$.tmp && mv /tmp/$$.tmp $f
done

pushd ${NAME}-$VERSION

dch -D $(lsb_release -cs) --newversion $VERSION-$RELEASE "Local automatic build"
debuild -uc -us -sa

fi
