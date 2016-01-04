# == Class: selinux::config
#
#  This class is designed to configure the system to use SELinux on the system
#
# === Parameters:
#  [*mode*]
#   (enforced|permissive|disabled) - sets the operating state for SELinux.
#
# Actions:
#  Configures SELinux to a specific state (enforced|permissive|disabled)
#
# Requires:
#  This module has no requirements
#
# Sample Usage:
#  This module should not be called directly.
#
class selinux::config(
  $mode=undef
) {
  Exec {
    path => '/bin:/sbin:/usr/bin:/usr/sbin',
  }

  package { 'libselinux-utils':
    ensure => present,
  }

  file { '/etc/selinux/config':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0444',
    content => template('selinux/sysconfig_selinux.erb')
  }

  $current_mode = $::selinux? {
    # lint:ignore:quoted_booleans
    false => 'disabled',
    false   => 'disabled',
    default => $::selinux_current_mode,
    # lint:endignore
  }
  # we don't always run setenforce
  if $current_mode != $mode {
    # only if there's change
    case $mode {
      'disabled': {
        # we can't apply right now disabled, but we can set it to permissive
        $change = "from ${current_mode} to ${mode}"
        notify { 'change':
          message => "A reboot is required to change ${change}"
        }
        if $current_mode == 'enforcing' {
          exec { 'setenforce permissive':
            require => Package['libselinux-utils'],
          }
        }
      }
      /^(permissive|enforcing)$/: {
        if $current_mode == 'disabled' {
          # we can't set disabled now, it needs a reboot.
          $change = "from ${current_mode} to ${mode}"
          notify { 'change':
            message => "A reboot is required to change ${change}"
          }
        } else {
          # we're going from permissive to enforcing or vice-versa
          exec { "setenforce ${mode}":
            require => Package['libselinux-utils'],
          }
        }
      }
      default: {
        fail('You must specify a mode (enforced, permissive, or disabled)')
      }
    }
  }
}
