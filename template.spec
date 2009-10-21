Summary: GPL Compression Libraries for Hadoop
Name: hadoop-gpl-compression
Version: @VERSION@
Release: 1
License: GPL
Source0: hadoop-gpl-compression-@VERSION@.tar.gz
Group: Development/Libraries
URL: http://code.google.com/p/hadoop-gpl-compression/
Packager: @PACKAGER@ <@PACKAGER_EMAIL@>
Buildroot: %{_tmppath}/%{name}-%{version}
BuildRequires: ant, gcc-g++, lzo-devel
Requires: lzo

%define hadoop_home @HADOOP_HOME@

%description
GPLed Compression Libraries for Hadoop, built at $DATE on $HOST

%prep
%setup
%build

ant -Dversion=%{version} compile-native package

%install
mkdir -p $RPM_BUILD_ROOT/%{hadoop_home}/lib
install -m644 $RPM_BUILD_DIR/%{name}-%{version}/build/%{name}-%{version}.jar $RPM_BUILD_ROOT/%{hadoop_home}/lib/
install -m644 $RPM_BUILD_DIR/%{name}-%{version}/build/%{name}-%{version}.jar $RPM_BUILD_ROOT/%{hadoop_home}/lib/
rsync -av $RPM_BUILD_DIR/%{name}-%{version}/build/%{name}-%{version}/lib/native/ $RPM_BUILD_ROOT/%{hadoop_home}/lib/native/

%files
%{hadoop_home}/lib/%{name}-%{version}.jar
%{hadoop_home}/lib/native/