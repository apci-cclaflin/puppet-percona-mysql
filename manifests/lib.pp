class mysqllib {

  include mysql::client

  define mysqldb( $user, $password, $db, $clienthost, $host = 'localhost', $privileges ) {
    exec { "create-${db}-db-${user}-${clienthost}":
      unless => "/usr/bin/mysql -h${host} -uroot -e \"SHOW GRANTS FOR '${user}'@'${clienthost}';\" | grep 'ON `${db}`.*'",
      command => "/usr/bin/mysql -h${host} -uroot -e \"CREATE DATABASE IF NOT EXISTS ${db}; GRANT ${privileges} ON ${db}.* TO '${user}'@'${clienthost}' IDENTIFIED BY '${password}'; FLUSH PRIVILEGES;\"",
      require => Service["mysql"],
    }
  }

}
