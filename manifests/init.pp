# mysql module
#
# Provides Percona-mysql package installation and configuration using hiera
# for server customization.
#
# @todo Document usage and convert this module to use the puppetlabs mysql
#       module constructs where possible.
# @link http://forge.puppetlabs.com/puppetlabs/mysql

class mysql {

  $mysql_percona_version = hiera('mysql_percona_version', '5.5.30-rel30.2-500.precise')

  apt::source { "percona":
    location    => "http://repo.percona.com/apt",
    release     => "${lsbdistcodename}",
    repos       => "main",
    include_src => true,
    key         => "CD2EFD2A",
    key_server  => "keys.gnupg.net",
  }

  package { "percona-server-common-5.5":
    ensure  => $mysql_percona_version,
    require => [ Apt::Source["percona"], Package["mysql-common"] ],
  }

  package { "mysql-common":
    ensure  => absent,
    require => [ Package["mysql-client"], Package["mysql-server"] ],
  }

}
