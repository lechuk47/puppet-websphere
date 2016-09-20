# == Class: was
#
# Full description of class was here.
#
# === Parameters
#
# Document parameters here.
#
# [*sample_parameter*]
#   Explanation of what this parameter affects and what it defaults to.
#   e.g. "Specify one or more upstream ntp servers as an array."
#
# === Variables
#
# Here you should define a list of variables that this module would require.
#
# [*sample_variable*]
#   Explanation of how this variable affects the funtion of this class and if
#   it has a default. e.g. "The parameter enc_ntp_servers must be set by the
#   External Node Classifier as a comma separated list of hostnames." (Note,
#   global variables should be avoided in favor of class parameters as
#   of Puppet 2.6.)
#
# === Examples
#
#  class { was:
#    servers => [ 'pool.ntp.org', 'ntp.local.company.com' ],
#  }
#
# === Authors
#
# Author Name <author@domain.com>
#
# === Copyright
#
# Copyright 2016 Your name here, unless otherwise noted.
#
class was (
  $profile_base               = '',
  $profile                    = '',
  $wsadmin_user               = '',
  $wsadmin_pass               = '',
  $cell                       = '',
  $nodename                   = '',
  $dumps_directory            = '',
  $servers                    = {},
  $application_servers        = {},
  $cluster_members            = {},
  $jvmProperties              = {},
  $server_environment_entries = {},
  $shared_libraries           = {},
  $jdbc_datasources           = {},
  ){

  $defaults = {
    profile_base    => $profile_base,
    profile         => $profile,
    wsadmin_user    => $wsadmin_user,
    wsadmin_pass    => $wsadmin_pass,
    nodename        => $nodename,
    cell            => $cell
  }

  notice($was_profiles)
  # create_resources(websphere_server, $servers, $defaults)
  create_resources(was::cluster_member, $cluster_members, $defaults)
  #create_resources(websphere_jvmproperty, $jvmProperties, $defaults)
  create_resources(was::server_environment_entry, $server_environment_entries, $defaults)
  #create_resources(was::application_server, $application_servers, $defaults)
  #create_resources(was::jvm_property, $jvmProperties, $defaults)
  create_resources(was::shared_library, $shared_libraries, $defaults)
  create_resources(was::jdbc_datasource, $jdbc_datasources, $defaults)
}
