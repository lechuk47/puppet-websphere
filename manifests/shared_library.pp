define was::shared_library(
  $cell                   = $::was::cell,
  $nodename               = $::was::nodename,
  $cluster                = undef,
  $server                 = undef,
  $profile_base           = $::was::profile_base,
  $profile                = $::was::profile,
  $wsadmin_user           = $::was::wsadmin_user,
  $wsadmin_pass           = $::was::wsadmin_pass,
  $scope                  = undef,
  $classpath              = undef,
  $description            = undef,
  $isolated_class_loader  = undef,
  ) {

    case $scope {
      'cell':    { $t = "${profile}:${scope}:$name" }
      'node':    { $t = "${profile}:${scope}:$nodename:$name" }
      'cluster': { $t = "${profile}:${scope}:$cluster:$name" }
      'server':  { $t = "${profile}:${scope}:$nodename:$server:$name" }
    }

    websphere_shared_library { $t:
        cell                  => $cell,
        nodename              => $nodename,
        server                => $server,
        profile_base          => $profile_base,
        profile               => $profile,
        wsadmin_user          => $wsadmin_user,
        wsadmin_pass          => $wsadmin_pass,
        scope                 => $scope,
        classpath             => $classpath,
        description           => $description,
        isolated_class_loader => $isolated_class_loader
    }


}
