Name: mysoftware
Version: 1.2.3
Release: 1%{?dist}
Summary: A really cool program
Group: Applications/Tools
License: GPL
URL: http://wittenberg.org
Source0: %{_sourcedir}/%{name}-%{version}.tar.gz
#BuildArch: noarch
#BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Packager: Daniel Wittenberg <dwittenberg2008@gmail.com>
Vendor: Important Software Vendor
#BuildRequires: autoconf, automake, pcre-devel
#Requires: libtool

%description
This is a really cool software package

### Build sub-package called %{name}-client ###
#%package client
#Summary: Sample Client sub-package
#Group: Utilities/Monitoring

#%description client
#Sample Client package
### END BUILD sub-package


%prep
%setup -q 

%build

%configure \
  	--prefix=%{_prefix} \
        --bindir=%{_sbindir} \
        --sysconfdir=%{_sysconfdir} \

%__make %{?_smp_mflags}

%check
%__make test

%install
%__rm -rf $RPM_BUILD_ROOT
%__mkdir_p -m 0755 $RPM_BUILD_ROOT%{_sbindir}
%__mkdir_p -m 0755 $RPM_BUILD_ROOT/%{_sysconfdir}/sysconfig
%__make install DESTDIR=$RPM_BUILD_ROOT


%pre

%post

%preun

%postun



%files
%defattr(-,root,root)
%attr(0755,root,root) %{_sbindir}/%{name}
%attr(0644,root,root) %{_mandir}/man8/%{name}.8.gz
%attr(0755,root,root) %dir %{_var}/log/%{name}

#%files client
#%attr(0755,root,root) %{_sbindir}/%{name}-client

%changelog
* Sun Apr 15 2012 Daniel Wittenberg <dwittenberg2008@gmail.com> 1.2.3-1
- Initial RPM build

