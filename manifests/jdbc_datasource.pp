define was::jdbc_datasource (
  $cell                         = $::was::cell,
  $profile_base                 = $::was::profile_base,
  $profile                      = $::was::profile,
  $wsadmin_user                 = $::was::wsadmin_user,
  $wsadmin_pass                 = $::was::wsadmin_pass,
  $nodename                     = $::was::nodename,
  $jdbc_provider                = undef,
  $scope                        = undef,
  $aged_timeout                 = undef,
  $auth_data_alias              = undef,
  $connection_timeout           = undef,
  $data_store_helper_class      = undef,
  $description                  = undef,
  $jndi_name                    = undef,
  $max_connections              = undef,
  $min_connections              = undef,
  $reap_time                    = undef,
  $statement_cache_size         = undef,
  $url                          = undef,
  $xa_recovery_auth_alias       = undef,

  ) {

    case $scope {
      'cell':    { $t = "${profile}:$name" }
      'node':    { $t = "${profile}:${scope}:$nodename:$name" }
      'cluster': { $t = "${profile}:${scope}:$cluster:$name" }
      'server':  { $t = "${profile}:${scope}:$nodename:$server:$name" }
    }

    websphere_jdbc_datasource { "$t":
      profile_base                 => $profile_base               ,
      profile                      => $profile                    ,
      cell                         => $cell                       ,
      wsadmin_user                 => $wsadmin_user               ,
      wsadmin_pass                 => $wsadmin_pass               ,
      nodename                     => $nodename                   ,
      jdbc_provider                => $jdbc_provider              ,
      scope                        => $scope                      ,
      aged_timeout                 => $aged_timeout               ,
      auth_data_alias              => $auth_data_alias            ,
      connection_timeout           => $connection_timeout         ,
      data_store_helper_class      => $data_store_helper_class,
      description                  => $description                ,
      jndi_name                    => $jndi_name                  ,
      max_connections              => $max_connections            ,
      min_connections              => $min_connections            ,
      reap_time                    => $reap_time                  ,
      statement_cache_size         => $statement_cache_size       ,
      url                          => $url                        ,
      xa_recovery_auth_alias       => $xa_recovery_auth_alias
    }

}
