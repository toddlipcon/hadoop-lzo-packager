#!/bin/bash -e

 

ARCH_BITS=${ARCH_BITS:-$SYSTEM_BITS}
BINDIR=$(dirname $0)
TOPDIR=$BINDIR/build/topdir
SVNURL=http://hadoop-gpl-compression.googlecode.com/svn/trunk/
SVN_REV=$(svn info $SVNURL | grep Revision | awk '{print $2}')
VERSION=0.2.0svn$SVN_REV
SVNCO=$BINDIR/hadoop-gpl-compression-$VERSION
SVNTAR=$BINDIR/hadoop-gpl-compression-$VERSION.tar.gz

if [ ! -d $SVNCO ]; then
  svn export -r $SVN_REV $SVNURL $SVNCO
fi

if [ ! -e $SVNTAR ]; then
  tar czf $SVNTAR $SVNCO
fi


VERSION=0.2.0svn$SVN_REV
PACKAGER=${PACKAGER:-$(getent passwd $USER | cut -d':' -f5 | cut -d, -f1)}
HOST=$(hostname -f)
PACKAGER_EMAIL=${PACKAGER_EMAIL:-$USER@$HOST}
HADOOP_HOME=${HADOOP_HOME:-/usr/lib/hadoop-0.20}

[[ $SVN_REV == [0-9]+ ]]

echo "SVN Revision: $SVN_REV"

##############################
# RPM
##############################

rm -Rf $TOPDIR
mkdir -p $TOPDIR

(cd $TOPDIR/ && mkdir SOURCES BUILD SPECS SRPMS RPMS BUILDROOT)

cat $BINDIR/template.spec | sed "
 s,@VERSION@,$VERSION,g;
 s,@PACKAGER@,$PACKAGER,g;
 s,@PACKAGER_EMAIL@,$PACKAGER_EMAIL,g;
 s,@HADOOP_HOME@,$HADOOP_HOME,g;
" > $TOPDIR/SPECS/hadoop-gpl-compression.spec

cp $SVNTAR $TOPDIR/SOURCES


##############################
# Deb
##############################
