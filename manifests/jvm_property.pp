define was::jvm_property(
  $cell                   = $::was::cell,
  $profile_base           = $::was::profile_base,
  $profile                = $::was::profile,
  $wsadmin_user           = $::was::wsadmin_user,
  $wsadmin_pass           = $::was::wsadmin_pass,
  $nodename               = $::was::nodename,
  $server                 = undef,
  $value                  = undef,
  $description            = undef
  ) {

    websphere_jvmproperty { "$profile:$nodename:$server:$name":
      cell                   => $cell,
      profile_base           => $profile_base,
      profile                => $profile,
      wsadmin_user           => $wsadmin_user,
      wsadmin_pass           => $wsadmin_pass,
      nodename               => $nodename,
      server                 => $server,
      value                  => $value,
      description            => $description
    }

}
