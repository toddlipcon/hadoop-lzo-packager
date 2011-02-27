#!/bin/bash -e
#
# Copyright (c) 2010, Cloudera, inc.
# All rights reserved.

set -x

ANT_VERSION="1.8.1"
ANT_TARBALL="apache-ant-${ANT_VERSION}-bin.tar.gz"
ANT_TARBALL_URL="http://www.gtlib.gatech.edu/pub/apache/ant/binaries/${ANT_TARBALL}"

setup_ant() {
    wget $WGET_OPTS -P "${BINDIR}/build" "${ANT_TARBALL_URL}"
    tar -C "${BINDIR}/build" -zxf "${BINDIR}/build/apache-ant-${ANT_VERSION}-bin.tar.gz"

    ANT_HOME="${BINDIR}/build/apache-ant-${ANT_VERSION}"
    PATH="${ANT_HOME}/bin:${PATH}"

    export PATH ANT_HOME
}

display_help() {
    echo "usage: $0 [-h][-D][-R][-a][-p <project>][-u <name>][-e <addr>][-H <host>][-r <release>][--svn-rev <rev>]"
    echo -e "
  Options:

    -h|--help               display help text
    -D|--no-deb             do not build debian packages
    -R|--no-rpm             do not build rpm packages

    Infrequently used:

    -r|--release <release>  release name or number (appended to the package version)
                            (default: 1)
    -p|--project <project>  source project from which to build where <project> is either
                            google-code or github.
                            (default: github)
    -u|--user <name>        username of the person creating the package
                            (default: ${USER})
    -e|--packager-email <addr>
                            email address of packager
                            (default: ${USER}@$(hostname -f))
    -H|--host               host on which the package was built
                            (default: $(hostname -f))
    --svn-rev <rev>         a specific subversion revision from which to build
    -a|--ant                handle ant trickery for me!
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
        -p|--project)
            SRC_PROJECT="$1"
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
        --svn-rev)
            SVN_REV="$1"
            shift
            ;;
        -a|--ant)
            _opt_handle_ant=1
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
# Which project to build.
#   github - builds the github fork hadoop-lzo project
#   googlecode - builds the original google code repo
SRC_PROJECT=${SRC_PROJECT:-github}

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

setup_googlecode() {
    SVNURL=${SVNURL:-http://hadoop-gpl-compression.googlecode.com/svn/trunk/}
    PACKAGE_HOMEPAGE=http://code.google.com/p/hadoop-gpl-compression/
    if [ -z "$SVN_REV" ]; then
        SVN_REV=$(svn info $SVNURL | grep Revision | awk '{print $2}')
        [[ $SVN_REV == [0-9]+ ]]
        echo "SVN Revision: $SVN_REV"
    fi
    VERSION=${VERSION:-0.2.0svn$SVN_REV}
    NAME=hadoop-gpl-compression
}

checkout_googlecode() {
    if [ ! -d $CHECKOUT ]; then
        svn export -r $SVN_REV $SVNURL $CHECKOUT
    fi
    CHECKOUT_TAR=$BINDIR/build/${NAME}-$VERSION.tar.gz
}

setup_github() {
    GITHUB_ACCOUNT=${GITHUB_ACCOUNT:-toddlipcon}
    GITHUB_BRANCH=${GITHUB_BRANCH:-master}
    PACKAGE_HOMEPAGE=http://github.com/$GITHUB_ACCOUNT/hadoop-lzo
    TARURL=http://github.com/$GITHUB_ACCOUNT/hadoop-lzo/tarball/$GITHUB_BRANCH
    if [ -z "$(ls $BINDIR/build/$GITHUB_ACCOUNT-hadoop*tar.gz)" ]; then
        wget $WGET_OPTS -P $BINDIR/build/ $TARURL
    fi
    ORIG_TAR=$(ls -1 $BINDIR/build/$GITHUB_ACCOUNT-hadoop*tar.gz | head -1)
    GIT_HASH=$(expr match $ORIG_TAR ".*hadoop-lzo-\(.*\).tar.gz")
    echo "Git hash: $GIT_HASH"
    NAME=${NAME:-$GITHUB_ACCOUNT-hadoop-lzo}
    VERSION=$(date +"%Y%m%d%H%M%S").$GIT_HASH

    pushd $BINDIR/build/ > /dev/null
    mkdir $NAME-$VERSION/
    tar -C $NAME-$VERSION/ --strip-components=1 -xzf $ORIG_TAR
    tar czf $NAME-$VERSION.tar.gz $NAME-$VERSION/
    popd > /dev/null

    CHECKOUT_TAR=$BINDIR/build/$NAME-$VERSION.tar.gz
}

checkout_github() {
    echo -n
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

setup_$SRC_PROJECT

TOPDIR=$BINDIR/build/topdir

CHECKOUT=$BINDIR/${NAME}-$VERSION
checkout_$SRC_PROJECT


if [ ! -e $CHECKOUT_TAR ]; then
  pushd $CHECKOUT
  cd ..
  tar czf $CHECKOUT_TAR $(basename $CHECKOUT)
  popd
fi

if [ -n "${_opt_handle_ant}" ] ; then
    setup_ant
fi

##############################
# RPM
##############################
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
