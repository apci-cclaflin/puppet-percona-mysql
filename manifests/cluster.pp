# mysql cluster module
#
# Provides Percona-xtradb-cluster package installation and configuration using hiera
# for server customization.

class mysql::cluster {

  $innodb_buffer_pool_size        = hiera('mysql_innodb_buffer_pool_size', '1G')
  $innodb_flush_log_at_trx_commit = hiera('mysql_innodb_flush_log_at_trx_commit')
  $innodb_log_file_repair	  = hiera('mysql_innodb_log_file_repair', 'false')
  $innodb_log_file_size           = hiera('mysql_innodb_log_file_size', '256M')
  $innodb_log_files_in_group      = hiera('mysql_innodb_log_files_in_group', 3)
  $max_allowed_packet             = hiera('mysql_max_allowed_packet', '64M')
  $max_connections                = hiera('mysql_max_connections', 155)
  $max_heap_table_size            = hiera('mysql_max_heap_table_size', '256M')
  $mysql_bin_log                  = hiera('mysql_bin_log', 'false')
  $mysql_log_slave_updates        = hiera('mysql_log_slave_updates', 'false')
  $mysql_percona_cluster_version  = hiera('mysql_percona_cluster_version', 'latest')
  $mysql_replicate_databases      = hiera('mysql_replicate_databases', 'false')
  $mysql_wildcard_ignore          = hiera('mysql_wildcard_ignore', 'false')
  $query_cache_size               = hiera('mysql_query_cache_size', '128M')
  $query_cache_limit              = hiera('mysql_query_cache_limit', '2M')
  $query_cache_type               = hiera('mysql_query_cache_type', '1')
  $tmp_table_size                 = hiera('mysql_tmp_table_size')
  $wsrep_cluster_bootstrap        = hiera('mysql_wsrep_cluster_bootstrap', 'false')
  $wsrep_cluster_address	  = hiera('mysql_wsrep_cluster_address', 'gcomm://')
  $wsrep_cluster_name		  = hiera('mysql_wsrep_cluster_name', 'mysql_cluster')
  $wsrep_clustercheck_user        = hiera('mysql_wsrep_clustercheck_user', 'clustercheckuser')
  $wsrep_clustercheck_pass        = hiera('mysql_wsrep_clustercheck_pass', 'clustercheckpassword!')
  $wsrep_slave_threads            = hiera('mysql_wsrep_slave_threads', 4)
  $wsrep_sst_user		  = hiera('mysql_wsrep_sst_user', 'sstuser')
  $wsrep_sst_pass                 = hiera('mysql_wsrep_sst_pass', 's3cretPass')
  $wsrep_sst_method               = hiera('mysql_wsrep_sst_method', 'xtrabackup')
  $ipaddr_oct3                    = regsubst($ipaddress,'^(\d+)\.(\d+)\.(\d+)\.(\d+)$','\3')
  $ipaddr_oct4                    = regsubst($ipaddress,'^(\d+)\.(\d+)\.(\d+)\.(\d+)$','\4')
  $server_id                      = "${ipaddr_oct3}${ipaddr_oct4}"

  import "./lib.pp"

  apt::source { "percona":
    location    => "http://repo.percona.com/apt",
    release     => "${lsbdistcodename}",
    repos       => "main",
    include_src => true,
    key         => "CD2EFD2A",
    key_server  => "keys.gnupg.net",
  }

  package { "percona-xtradb-cluster-server-5.5":
    ensure  => $mysql_percona_cluster_version,
    require => Apt::Source["percona"], 
  }

  package { "percona-xtradb-cluster-client-5.5":
    ensure  => $mysql_percona_cluster_version,
    require => [ Apt::Source["percona"], Package["percona-xtradb-cluster-server-5.5"] ],
  }

  package { "percona-xtradb-cluster-galera-2.x":
    ensure  => "latest",
    require => [ Apt::Source["percona"], Package["percona-xtradb-cluster-server-5.5"] ],
  }

  package { "xinetd":
    ensure  => "latest",
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

  file { "/usr/local/bin/mysql-check-file-sizes":
    owner   => root,
    group   => root,
    mode    => 755,
    content => template('mysql/mysql-check-file-sizes.erb'),
  }

  case $innodb_log_file_repair {
    "true": {
      $mysql_check_command = "mysql-check-file-sizes /var/lib/mysql repair"
    }
    default: {
      $mysql_check_command = "mysql-check-file-sizes /var/lib/mysql"
    }
  }

  exec { "mysql-check-file-sizes":
    command     => "${mysql_check_command}",
    path        => "/usr/bin:/usr/sbin:/bin:/usr/local/bin:/sbin",
    before      => Service["mysql"],
    require     => [ Package["percona-xtradb-cluster-server-5.5"], File["/usr/local/bin/mysql-check-file-sizes"] ],
    refreshonly => true,
  }

  service {"mysql":
    enable  => true,
    ensure  => running,
    require => Package["percona-xtradb-cluster-server-5.5"],
  } 

  file { "/etc/mysql":
    ensure => directory,
    owner => root,
    group => root,
    mode => 755,
  }

  file { "/etc/mysql/my.cnf":
    owner   => root,
    group   => root,
    mode    => 644,
    content => template('mysql/my-cluster.cnf.erb'),
    notify  => [ Service["mysql"], Exec["mysql-check-file-sizes"] ],
    require => File["/etc/mysql"],
  }

  exec { "create-wsrep-user":
    unless => "/usr/bin/mysql -hlocalhost -uroot -e \"SHOW GRANTS FOR '${wsrep_sst_user}'@'localhost';\" | grep 'GRANT RELOAD, LOCK TABLES, REPLICATION'",
    command => "/usr/bin/mysql -hlocalhost -uroot -e \"GRANT RELOAD, LOCK TABLES, REPLICATION CLIENT ON *.* TO '${wsrep_sst_user}'@'localhost' IDENTIFIED BY '${wsrep_sst_pass}'; FLUSH PRIVILEGES;\"",
    require => Service["mysql"],
  }

  exec { "create-clustercheck-user":
    unless => "/usr/bin/mysql -hlocalhost -uroot -e \"SHOW GRANTS FOR '${wsrep_clustercheck_user}'@'localhost';\" | grep 'GRANT PROCESS ON'",
    command => "/usr/bin/mysql -hlocalhost -uroot -e \"GRANT PROCESS ON *.* TO '${wsrep_clustercheck_user}'@'localhost' IDENTIFIED BY '${wsrep_clustercheck_pass}'; FLUSH PRIVILEGES;\"",
    require => Service["mysql"],
  }

  file { "/usr/bin/clustercheck":
    owner   => root,
    group   => root,
    mode    => 755,
    content => template('mysql/clustercheck.erb'),
    require => Package["percona-xtradb-cluster-server-5.5"],
  }

}
