define was::cluster_member (
  $cell                             = $::was::cell,
  $nodename                         = $::was::nodename,
  $profile_base                     = $::was::profile_base,
  $profile                          = $::was::profile,
  $wsadmin_user                     = $::was::wsadmin_user,
  $wsadmin_pass                     = $::was::wsadmin_pass,
  $cluster                          = undef,
  $umask                            = undef,
  $runas_user                       = undef,
  $runas_group                      = undef,
  $jvm_initial_heap_size            = undef,
  $jvm_maximum_heap_size            = undef,
  $jvm_generic_jvm_arguments        = undef,
  $plugin_props_connect_timeout     = undef,
  $plugin_props_server_io_timeout   = undef,
  $threadpool_webcontainer_min_size = undef,
  $threadpool_webcontainer_max_size = undef,
  $jvm_verbose_garbage_collection   = undef,
  $server_environment_entries       = undef,
  $sysout_rotation_type             = undef,
  $sysout_rotation_size             = undef,
  $sysout_rotation_backups          = undef,
  $sysout_rotation_hour             = undef,
  $sysout_rotation_period           = undef,
  $syserr_rotation_type             = undef,
  $syserr_rotation_size             = undef,
  $syserr_rotation_backups          = undef,
  $syserr_rotation_hour             = undef,
  $syserr_rotation_period           = undef,
  $jvm_properties                   = undef,

) {

    websphere_cluster_member { "${profile}:${nodename}:${cluster}:${name}":
      cell                             => $cell,
      nodename                         => $nodename,
      cluster                          => $cluster,
      profile_base                     => $profile_base,
      profile                          => $profile,
      wsadmin_user                     => $wsadmin_user,
      wsadmin_pass                     => $wsadmin_pass,
      umask                            => $umask,
      runas_user                       => $runas_user,
      runas_group                      => $runas_group,
      jvm_initial_heap_size            => $jvm_initial_heap_size,
      jvm_maximum_heap_size            => $jvm_maximum_heap_size,
      jvm_generic_jvm_arguments        => $jvm_generic_jvm_arguments,
      plugin_props_connect_timeout     => $plugin_props_connect_timeout,
      plugin_props_server_io_timeout   => $plugin_props_server_io_timeout,
      threadpool_webcontainer_min_size => $threadpool_webcontainer_min_size,
      threadpool_webcontainer_max_size => $threadpool_webcontainer_max_size,
      jvm_verbose_garbage_collection   => $jvm_verbose_garbage_collection,
      sysout_rotation_type             => $sysout_rotation_type   ,
      sysout_rotation_size             => $sysout_rotation_size   ,
      sysout_rotation_backups          => $sysout_rotation_backups,
      sysout_rotation_hour             => $sysout_rotation_hour   ,
      sysout_rotation_period           => $sysout_rotation_period ,
      syserr_rotation_type             => $syserr_rotation_type   ,
      syserr_rotation_size             => $syserr_rotation_size   ,
      syserr_rotation_backups          => $syserr_rotation_backups,
      syserr_rotation_hour             => $syserr_rotation_hour   ,
      syserr_rotation_period           => $syserr_rotation_period ,
    }

    $defaults = {
      cell            => $cell,
      profile_base    => $profile_base,
      profile         => $profile,
      wsadmin_user    => $wsadmin_user,
      wsadmin_pass    => $wsadmin_pass,
      nodename        => $nodename,
      server          => $name,
      require         => Websphere_Cluster_Member["$profile:$nodename:$cluster:$name"]
    }

    $jvm_props2 = prefix_hash($jvm_properties, "$profile:$nodename:$name:")
    create_resources(websphere_jvmproperty, $jvm_props2, $defaults)


    # $jvm_props3 = {
    #   'sun.net.http.allowRestrictedHeaders' => {
    #     value => 'true'
    #   },
    #   'sun.net.inetaddr.ttl' => {
    #     value => '0'
    #   },
    #   'sun.net.inetaddr.negative.ttl' => {
    #     value => '0'
    #   } ,
    #   'disableWSAddressCaching' => {
    #     value => 'true'
    #   }
    # }
    #
    # $jvm_props33 = prefix_hash($jvm_props3, "$profile:$nodename:$name:")
    # create_resources(websphere_jvmproperty, $jvm_props33, $defaults)


    $server_environment_entries2 = prefix_hash($server_environment_entries, "$profile:$nodename:$name:")
    create_resources(websphere_server_environment_entry, $server_environment_entries2, $defaults)


}
