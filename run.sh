#!/bin/bash -e
set -x
##############################
# Begin configurables
##############################
SVNURL=${SVNURL:-http://hadoop-gpl-compression.googlecode.com/svn/trunk/}
if [ -z "$SVN_REV" ]; then
  SVN_REV=$(svn info $SVNURL | grep Revision | awk '{print $2}')
fi
VERSION=${VERSION:-0.2.0svn$SVN_REV}
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
TOPDIR=$BINDIR/build/topdir

SVNCO=$BINDIR/hadoop-gpl-compression-$VERSION
SVNTAR=$BINDIR/build/hadoop-gpl-compression-$VERSION.tar.gz
mkdir -p build
if [ ! -d $SVNCO ]; then
  svn export -r $SVN_REV $SVNURL $SVNCO
fi

if [ ! -e $SVNTAR ]; then
  pushd $SVNCO
  cd ..
  tar czf $SVNTAR $(basename $SVNCO)
  popd
fi


[[ $SVN_REV == [0-9]+ ]]

echo "SVN Revision: $SVN_REV"

##############################
# RPM
##############################
if [ -z "$SKIP_RPM" ]; then
rm -Rf $TOPDIR
mkdir -p $TOPDIR

(cd $TOPDIR/ && mkdir SOURCES BUILD SPECS SRPMS RPMS BUILDROOT)

cat $BINDIR/template.spec | sed "
 s,@VERSION@,$VERSION,g;
 s,@RELEASE@,$RELEASE,g;
 s,@PACKAGER@,$PACKAGER,g;
 s,@PACKAGER_EMAIL@,$PACKAGER_EMAIL,g;
 s,@HADOOP_HOME@,$HADOOP_HOME,g;
" > $TOPDIR/SPECS/hadoop-gpl-compression.spec

cp $SVNTAR $TOPDIR/SOURCES

pushd $TOPDIR/SPECS > /dev/null
rpmbuild $RPMBUILD_FLAGS \
  --buildroot $(pwd)/../BUILDROOT \
  --define "_topdir $(pwd)/.." \
  -ba hadoop-gpl-compression.spec
popd
fi

##############################
# Deb
##############################
if [ -z "$SKIP_DEB"]; then
DEB_DIR=$BINDIR/build/deb
mkdir -p $DEB_DIR
rm -Rf $DEB_DIR

mkdir $DEB_DIR
cp -a $SVNTAR $DEB_DIR/hadoop-gpl-compression_$VERSION.orig.tar.gz
pushd $DEB_DIR
tar xzf *.tar.gz
cp -a $BINDIR/debian/ hadoop-gpl-compression-$VERSION
pushd hadoop-gpl-compression-$VERSION

dch -D $(lsb_release -cs) --newversion $VERSION-$RELEASE "Local automatic build"
debuild -uc -us -sa

fi
