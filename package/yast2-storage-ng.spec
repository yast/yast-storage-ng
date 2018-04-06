#
# spec file for package yast2-storage-ng
#
# Copyright (c) 2018 SUSE LLC.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#

Name:		yast2-storage-ng
Version:        4.0.149
Release:	0
BuildArch:	noarch

BuildRoot:	%{_tmppath}/%{name}-%{version}-build
Source:		%{name}-%{version}.tar.bz2

# Yast::Report.yesno_popup
Requires:	yast2 >= 4.0.61
Requires:	yast2-ruby-bindings
# ResizeInfo::reasons() and RB_ enum
Requires:	libstorage-ng-ruby >= 3.3.198

BuildRequires:	update-desktop-files
# ResizeInfo::reasons() and RB_ enum
BuildRequires:	libstorage-ng-ruby >= 3.3.198
BuildRequires:	yast2-ruby-bindings
BuildRequires:	yast2-devtools
# yast2-xml dependency is added by yast2 but ignored in the
# openSUSE:Factory project config
BuildRequires:  yast2-xml
# Yast::Report.yesno_popup
BuildRequires:	yast2 >= 4.0.61
BuildRequires:	rubygem(yast-rake)
BuildRequires:	rubygem(rspec)
PreReq:         %fillup_prereq

Obsoletes:	yast2-storage

Group:		System/YaST
License:	GPL-2.0 or GPL-3.0
Summary:	YaST2 - Storage Configuration

%description
This package contains the files for YaST2 that handle access to disk
devices during installation and on an installed system.
This YaST2 module uses libstorage-ng.

%prep
%setup -n %{name}-%{version}

%check
rake test:unit

%install
rake install DESTDIR="%{buildroot}"

%post
%ifarch s390 s390x
%{fillup_only -ans storage %{name}.s390}
%else
%{fillup_only -ans storage %{name}.default}
%endif

%files
%defattr(-,root,root)
%{yast_dir}/clients/*.rb
%{yast_dir}/lib
%{yast_desktopdir}/*.desktop
%{yast_fillupdir}/*

# agents-scr
%{yast_scrconfdir}/*.scr

%doc COPYING
%doc README.md
%doc CONTRIBUTING.md

%build
