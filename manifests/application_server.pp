define was::application_server (
  $cell                             = $::was::cell,
  $nodename                         = $::was::nodename,
  $profile_base                     = $::was::profile_base,
  $profile                          = $::was::profile,
  $wsadmin_user                     = $::was::wsadmin_user,
  $wsadmin_pass                     = $::was::wsadmin_pass,
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
  $jvm_properties                    = undef,
  $server_environment_entries       = undef

){
    websphere_application_server { "${profile}:${nodename}:${name}":
      cell                             => $cell,
      nodename                         => $nodename,
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
      jvm_verbose_garbage_collection   => $jvm_verbose_garbage_collection
    }

    $defaults = {
      profile_base    => $profile_base,
      profile         => $profile,
      wsadmin_user    => $wsadmin_user,
      wsadmin_pass    => $wsadmin_pass,
      nodename        => $nodename,
      cell            => $cell,
      server          => $name,
      require         => Websphere_Application_Server["$profile:$nodename:$name"]
    }


    #notice($jvmProperties)
    # create_resources(jvm_property, $jvmProperties, $defaults)
    # create_resources(websphere_server_environment_entry, $server_environment_entries, $defaults)
    $jvm_props2 = prefix_hash($jvm_properties, "$profile:$nodename:$name:")
    create_resources(websphere_jvmproperty, $jvm_props2, $defaults)

    $server_environment_entries2 = prefix_hash($server_environment_entries, "$profile:$nodename:$name:")
    create_resources(websphere_server_environment_entry, $server_environment_entries2, $defaults)
}
