class jboss::addons::mod_cluster (
  $version          = $jboss::params::version,
) inherits jboss::params {
  
  include apache
  include jboss::params::mod_cluster

  # FIXME - tu jest ver, wyżej jest version - które lepsze?
  $ver = $jboss::params::mod_cluster::version

  # Install RPM containing mod_cluster, then unpack it to the modules directory
  $download_file = "mod_cluster-${ver}-linux2-x64-so.tar.gz"
  package { "$download_file": }

  # TODO - probably there's a var for etc/httpd/modules
  exec { 'untar-mod_cluster':
    command => "/bin/tar -C /etc/httpd/modules -xvf /usr/src/${download_file}",
    subscribe => Package["$download_file"]
  }
  
  # mod_cluster module config
  apache::mod { 'slotmem': }
  apache::mod { 'manager': }
  apache::mod { 'proxy': }
  apache::mod { 'proxy_cluster': }
  apache::mod { 'advertise': }

  # Listening
  #apache::listen { '80': }
  #apache::listen { '81': }
  #apache::listen { '10001': }

  # X-Forwarded-For
  #$log_formats = { vhost_common => '%v %h %l %u %t \"%r\" %>s %b' }

  file { "mod_cluster_conf":
    path => '/etc/httpd/conf.d/00-mod_cluster.conf',
    content => '
MemManagerFile /var/cache/httpd
Maxsessionid 100',
  }


  file { "parameters_conf":
    path => '/etc/httpd/conf.d/01-parameters.conf',
    content => '
    ServerTokens Off
    '
  }
  
  # vhosts
  apache::vhost { 'mgmt-mod_cluster':
    ip => $ipaddress_eth2, # Management interface!
    priority => 30,
    ip_based => true,
    port    => 10001,
    docroot => '/var/www/html',
    custom_fragment => "

    <Directory />
      Options +Indexes
      Order deny,allow
      Deny from all
      Allow from 172.
    </Directory>

    # This directive allows you to view mod_cluster status at URL /mod_cluster-manager
    <Location /mod_cluster-manager>
      SetHandler mod_cluster-manager
      Order deny,allow
      Deny from all
      Allow from 172.
    </Location>

    <Location /server-status>
      SetHandler server-status
      Order deny,allow
      Deny from all
      Allow from all
    </Location>

    KeepAliveTimeout 60
    MaxKeepAliveRequests 0

    AdvertiseBindAddress ${ipaddress_eth2}:23364
    EnableMCPMReceive On

    ManagerBalancerName web-group
    AdvertiseFrequency 3
    "
  }

}