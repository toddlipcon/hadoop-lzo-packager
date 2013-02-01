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
%define _use_internal_dependency_generator 0

%define install_dir @INSTALL_DIR@

%description
GPLed Compression Libraries for Hadoop, built at $DATE on $HOST

%prep
%setup

# Requires: exclude libjvm.so since it generally isn't installed
# on the system library path, and we don't want to have to install
# with --nodeps
# RHEL doesn't have nice macros. Oh well. Do it old school.
%define our_req_script %{name}-find-req.sh
cat <<__EOF__ > %{our_req_script}
#!/bin/sh
%{__find_requires} | grep -v libjvm
__EOF__
%define __find_requires %{_builddir}/%{name}-%{version}/%{our_req_script}
chmod +x %{__find_requires}

%build

ant -Dname=%{name} -Dversion=%{version} compile-native package

%install
mkdir -p $RPM_BUILD_ROOT/%{install_dir}/lib
install -m644 $RPM_BUILD_DIR/%{name}-%{version}/build/%{name}-%{version}.jar $RPM_BUILD_ROOT/%{install_dir}/lib/
rsync -av --no-t $RPM_BUILD_DIR/%{name}-%{version}/build/%{name}-%{version}/lib/native/ $RPM_BUILD_ROOT/%{install_dir}/lib/native/

%files
%{install_dir}/lib/%{name}-%{version}.jar
%{install_dir}/lib/native/
