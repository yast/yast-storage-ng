#
# spec file for package yast2-storage-ng
#
# Copyright (c) 2015 SUSE LLC.
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
Version:        0.1.17
Release:	0
BuildArch:	noarch

BuildRoot:	%{_tmppath}/%{name}-%{version}-build
Source:		%{name}-%{version}.tar.bz2

Requires:	yast2
Requires:	yast2-ruby-bindings
Requires:	libstorage-ng-ruby

BuildRequires:	update-desktop-files
BuildRequires:	libstorage-ng-ruby
BuildRequires:	yast2-ruby-bindings
BuildRequires:	yast2-devtools
BuildRequires:	yast2
BuildRequires:	rubygem(yast-rake)
BuildRequires:	rubygem(rspec)

Group:		System/YaST
License:	GPL-2.0 or GPL-3.0
Summary:	YaST2 - Example module using libstorage-ng

%description
A YaST2 example module using libstorage-ng.

%prep
%setup -n %{name}-%{version}

%check
rake test:unit

%install
rake install DESTDIR="%{buildroot}"

%files
%defattr(-,root,root)
%{yast_dir}/clients/*.rb
%{yast_dir}/lib

# agents-scr
%{yast_scrconfdir}/*.scr

%doc COPYING
%doc README.md

%build
