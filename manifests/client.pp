class mysql::client {

  $mysql_percona_version = hiera('mysql_percona_version', '5.5.30-rel30.2-500.precise')

  include mysql

  package { "libmysqlclient18":
    ensure  => $mysql_percona_version,
    require => Apt::Source["percona"],
  }

  package { "libmysqlclient-dev":
    ensure  => $mysql_percona_version,
    require => [ Package["libmysqlclient18"], Apt::Source["percona"] ],
  }

  package {
    "percona-server-client-5.5": 
      ensure  => $mysql_percona_version,
      require => [ Package["libmysqlclient-dev"], Package["mysql-client"], Package["percona-server-common-5.5"], Apt::Source["percona"] ];
    "mysql-client":
      ensure  => absent,
      require => Package["mysql-client-core-5.5"];
    "mysql-client-core-5.5":
      ensure  => absent;
  }

  if !defined(Package["mysql-server"]) {
    package { 
      "mysql-server":
        ensure  => absent,
        require => Package["mysql-server-core-5.5"];
      "mysql-server-core-5.5":
        ensure  => absent; 
    }
  }

}
