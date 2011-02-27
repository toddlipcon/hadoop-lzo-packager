Summary: GPL Compression Libraries for Hadoop
Name: @PACKAGE_NAME@
Version: @VERSION@
Release: @RELEASE@
License: GPL
Source0: @PACKAGE_NAME@-@VERSION@.tar.gz
Group: Development/Libraries
URL: @PACKAGE_HOMEPAGE@
Packager: @PACKAGER@ <@PACKAGER_EMAIL@>
Buildroot: %{_tmppath}/%{name}-%{version}
BuildRequires: ant, ant-nodeps, gcc-c++, lzo-devel
Requires: lzo

%define hadoop_home @HADOOP_HOME@
%define hbase_home @HBASE_HOME@

%description
GPLed Compression Libraries for Hadoop, built at $DATE on $HOST

%prep
%setup
%build

ant -Dname=%{name} -Dversion=%{version} compile-native package

%install
mkdir -p $RPM_BUILD_ROOT/%{hadoop_home}/lib
JAR_NAME=%{name}-%{version}.jar
install -m644 $RPM_BUILD_DIR/%{name}-%{version}/build/$JAR_NAME $RPM_BUILD_ROOT/%{hadoop_home}/lib/
rsync -av --no-t $RPM_BUILD_DIR/%{name}-%{version}/build/%{name}-%{version}/lib/native/ $RPM_BUILD_ROOT/%{hadoop_home}/lib/native/

# For HBase: link to the hadoop files
mkdir -p $RPM_BUILD_ROOT/%{hbase_home}/lib
ln -s %{hadoop_home}/lib/native $RPM_BUILD_ROOT/%{hbase_home}/lib/native
ln -s %{hadoop_home}/lib/$JAR_NAME $RPM_BUILD_ROOT/%{hbase_home}/lib/$JAR_NAME

%files
%{hadoop_home}/lib/%{name}-%{version}.jar
%{hadoop_home}/lib/native/
%{hbase_home}/lib/%{name}-%{version}.jar
%{hbase_home}/lib/native/
