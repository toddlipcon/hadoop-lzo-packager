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

%description
GPLed Compression Libraries for Hadoop, built at $DATE on $HOST

%prep
%setup
%build

ant -Dname=%{name} -Dversion=%{version} compile-native package

%install
mkdir -p $RPM_BUILD_ROOT/%{hadoop_home}/lib
install -m644 $RPM_BUILD_DIR/%{name}-%{version}/build/%{name}-%{version}.jar $RPM_BUILD_ROOT/%{hadoop_home}/lib/
install -m644 $RPM_BUILD_DIR/%{name}-%{version}/build/%{name}-%{version}.jar $RPM_BUILD_ROOT/%{hadoop_home}/lib/
rsync -av --no-t $RPM_BUILD_DIR/%{name}-%{version}/build/%{name}-%{version}/lib/native/ $RPM_BUILD_ROOT/%{hadoop_home}/lib/native/

%files
%{hadoop_home}/lib/%{name}-%{version}.jar
%{hadoop_home}/lib/native/
