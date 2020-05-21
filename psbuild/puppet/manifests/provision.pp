include prepare_windows

include set_windows_autologon

include configure_windows_networking

# The Chocolatey provider does not have the ability to install from a local
# nupkg so install it first here.
include chocolatey_local_install

include chocolatey_configure

case $operatingsystem {
  'windows': {
    Package { provider => chocolatey, }
  }
}

# disable the Chocolatey source
chocolateysource { 'chocolatey':
  ensure => disabled,
}

include vm_guest_tools

include setup_bginfo

$packages_install = [ "git", "iridium-browser", "firefox", "notepadplusplus", "nuget.commandline", "syspin" ]
package { $packages_install:
  ensure => installed,
}

# dont install any PowerShell modules here as it's importabt they are installed from the moduel build
