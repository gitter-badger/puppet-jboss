class jboss::internal::params {

  # Directory to download installation temporary files
  $download_rootdir = hiera('jboss::internal::params::download_rootdir', '/usr/src')

  #Directory for logging
  $logdir = hiera('jboss::internal::params::logdir', '/var/log/jboss')

  # File for logging
  $logfile = hiera('jboss::internal::params::logfile', "${logdir}/console.log")

  include jboss::internal::params::socketbinding
  include jboss::internal::params::memorydefaults
}
