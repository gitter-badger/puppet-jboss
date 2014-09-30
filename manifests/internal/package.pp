class jboss::internal::package (
  $jboss_user       = $jboss::params::jboss_user,
  $jboss_group      = $jboss::params::jboss_group,
  $package_name     = $jboss::params::package_name,
  $version          = $jboss::params::version,
  $java_autoinstall = $jboss::params::java_autoinstall,
  $java_version     = $jboss::params::java_version,
  $java_package     = $jboss::params::java_package,
  $install_dir      = $jboss::params::install_dir,
  # Prerequisites class, that can be overwritten
  $prerequisites    = Class['jboss::internal::prerequisites'],
) inherits jboss::params {
  include jboss
  include jboss::internal::runtime
  
  $dir              = '/usr/src/'
  $home             = $jboss::home
  
  $logdir     = $jboss::internal::params::logdir
  $logfile    = $jboss::internal::params::logfile
  $configfile = $jboss::internal::runtime::configfile
  
  case $version {
    /^(?:eap|as)-[0-9]+\.[0-9]+\.[0-9]+[\._-][0-9a-zA-Z_-]+$/: {
      debug("Running in version: $1 -> $version")
    }
    default: {
      fail("Invalid Jboss version passed: `$version`! Pass valid version for ex.: `eap-6.1.0.GA`")
    }
  }

  anchor { "jboss::package::begin":
    require => Anchor['jboss::begin'],
  }

  File {
    owner => $jboss_user,
    group => $jboss_group,
    mode  => '2750',
  }

  Exec {
    path      => "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
    logoutput => 'on_failure',
  }

  if (!defined(Group[$jboss_group])) {
    group { $jboss_group: ensure => 'present', }
  }

  if (!defined(User[$jboss_user])) {
    user { $jboss_user:
      ensure     => 'present',
      managehome => true,
      gid        => $jboss_group,
    }
  }

  file { 'jboss::confdir':
    path   => '/etc/jboss-as',
    ensure => 'directory',
    owner  => 'root',
    group  => 'root',
    mode   => '755',
  }
  
  file { 'jboss::logdir':
    path   => $logdir,
    ensure => 'directory',
    owner  => 'root',
    group  => $jboss_group,
    mode   => '2770',
  }
  
  file { 'jboss::logfile':
    path   => $logfile,
    ensure => 'file',
    owner  => 'root',
    group  => $jboss_group,
    mode   => '0660',
  }
  
  if $java_autoinstall {
    class { 'java':
      distribution => 'jdk',
      version      => $java_version,
      package      => $java_package,
      notify       => Service['jboss'],
    }
    Class['java'] -> Exec['jboss::package::check-for-java']
  }

  package { "${package_name}":
    ensure => 'present',
  }

  exec { 'jboss::unzip-downloaded':
    command => "unzip -o -q ${dir}/${package_name} -d ${jboss::home}",
    cwd     => $download_dir,
    creates => $jboss::home,
    require => [
      $prerequisites, # Prerequisites class, that can be overwritten
      Package["${package_name}"],
      Package['unzip'],
    ],
  }

  exec { 'jboss::move-unzipped':
    command => "mv ${jboss::home}/*/* ${jboss::home}/",
    creates => "${jboss::home}/bin",
    require => Exec['jboss::unzip-downloaded'],
  }


  exec { 'jboss::test-extraction':
    command => "echo '${jboss::home}/bin/init.d not found!' 1>&2 && exit 1",
    unless  => "test -d ${jboss::home}/bin/init.d",
    require => Exec['jboss::move-unzipped'],
  }

  jboss::internal::util::groupaccess { $jboss::home:
    user    => $jboss_user,
    group   => $jboss_group,
    require => [
      User[$jboss_user], 
      Exec['jboss::test-extraction'],
    ],
  }

  file { 'jboss::service-link::domain':
    ensure  => 'link',
    path    => '/etc/init.d/jboss-domain',
    target  => "${jboss::home}/bin/init.d/jboss-as-domain.sh",
    require => Jboss::Internal::Util::Groupaccess[$jboss::home],
  }
  
  file { 'jboss::service-link::standalone':
    ensure  => 'link',
    path    => '/etc/init.d/jboss-standalone',
    target  => "${jboss::home}/bin/init.d/jboss-as-standalone.sh",
    require => Jboss::Internal::Util::Groupaccess[$jboss::home],
  }
  
  file { 'jboss::configuration-link::domain':
    ensure  => 'link',
    path    => '/etc/jboss-as/domain.xml',
    target  => "${jboss::home}/domain/configuration/domain.xml",
    require => Jboss::Internal::Util::Groupaccess[$jboss::home],
  }
  $hostfile = 'host.xml'
  file { 'jboss::configuration-link::host':
    ensure  => 'link',
    path    => "/etc/jboss-as/${hostfile}",
    target  => "${jboss::home}/domain/configuration/${hostfile}",
    require => Jboss::Internal::Util::Groupaccess[$jboss::home],
  }
  
  file { 'jboss::configuration-link::standalone':
    ensure  => 'link',
    path    => '/etc/jboss-as/standalone.xml',
    target  => "${jboss::home}/standalone/configuration/${configfile}",
    require => Jboss::Internal::Util::Groupaccess[$jboss::home],
  }
  
  file { 'jboss::service-link':
    ensure  => 'link',
    path    => '/etc/init.d/jboss',
    target  => $jboss::runasdomain ? {
      true    => '/etc/init.d/jboss-domain',
      default => '/etc/init.d/jboss-standalone',
    },
    require => Jboss::Internal::Util::Groupaccess[$jboss::home],
    notify  => [
      Exec['jboss::kill-existing::domain'],
      Exec['jboss::kill-existing::standalone'],
    ],
  }
  
  exec { 'jboss::kill-existing::domain':
    command     => '/etc/init.d/jboss-domain stop',
    refreshonly => true,
    onlyif      => '/etc/init.d/jboss-domain status',
    before      => Service['jboss'],
  }
  
  exec { 'jboss::kill-existing::standalone':
    command     => '/etc/init.d/jboss-standalone stop',
    refreshonly => true,
    onlyif      => '/etc/init.d/jboss-standalone status',
    before      => Service['jboss'],
  }
  
  file { 'jboss::jbosscli':
    content => template('jboss/jboss-cli.erb'),
    mode    => 755,
    path    => '/usr/bin/jboss-cli',
    require => Jboss::Internal::Util::Groupaccess[$jboss::home],
  }
  
  exec { 'jboss::package::check-for-java':
    command => 'echo "Please provide Java executable to system!" 1>&2 && exit 1',
    unless  => "[ `which java` ] && java -version 2>&1 | grep -q 'java version'",
    require => Anchor["jboss::installed"],
    before  => Anchor["jboss::package::end"],
  }

  anchor { "jboss::installed":
    require => [
      Jboss::Internal::Util::Groupaccess[$jboss::home],
      Exec['jboss::test-extraction'],
      File['jboss::confdir'],
      File['jboss::logfile'],
      File['jboss::jbosscli'],
      File['jboss::service-link'],
    ],
    before  => Anchor["jboss::package::end"], 
  }
  anchor { "jboss::package::end": }
}