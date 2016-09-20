require 'pathname'

Puppet::Type.newtype(:websphere_jdbc_datasource) do

  # autorequire(:user) do
  #   self[:user]
  # end

  # autorequire(:websphere_jdbc_provider) do
  #   self[:jdbc_provider]
  # end


  #relationalResourceAdapter
  #description
  #manageCachedHandles
  #type
  #xaRecoveryAuthAlias
  #id
  #authMechanismPreference
  #datasourceHelperClassname
  #jndiName
  #logMissingTransactionContext
  #statementCacheSize
  #authDataAlias
  #name
  #diagnoseConnectionUsage
  #providerType

  ensurable

  # newparam(:dmgr_profile) do
  #   desc <<-EOT
  #   The dmgr profile that this should be created under"
  #   Example: dmgrProfile01"
  #   EOT
  #
  #   validate do |value|
  #     unless value =~ /^[-0-9A-Za-z._]+$/
  #       fail("Invalid dmgr_profile #{value}")
  #     end
  #   end
  # end

  def self.title_patterns
    [
      [
        /^(.*):(.*)/,
        [
          [:profile, lambda{|x| x}  ],
          [:name, lambda{|x| x} ]
        ],
        /^(.*):node:(.*):(.*)/,
        [
          [:profile, lambda{|x| x}  ],
          [:nodename, lambda{|x| x} ],
          [:name, lambda{|x| x} ]
        ],
        /^(.*):cluster:(.*):(.*)/,
        [
          [:profile, lambda{|x| x}  ],
          [:cluster, lambda{|x| x} ],
          [:name, lambda{|x| x} ]
        ],
        /^(.*):server:(.*):(.*):(.*)/,
        [
          [:profile, lambda{|x| x}  ],
          [:node, lambda{|x| x} ],
          [:server, lambda{|x| x} ],
          [:name, lambda{|x| x} ]
        ],
      ]
    ]
  end



  newparam(:profile_base) do
    desc <<-EOT
    The base directory that profiles are stored.
    Basically, where can we find the 'dmgr_profile' so we can run 'wsadmin'
    Example: /opt/IBM/WebSphere/AppServer/profiles"
    EOT

    validate do |value|
      fail("Invalid profile_base #{value}") unless Pathname.new(value).absolute?
    end
  end

  newparam(:name) do
    isnamevar
  end
  newparam(:profile) do
    isnamevar
  end

  newparam(:nodename) do
    isnamevar
  end

  newparam(:server) do
    isnamevar
  end

  newparam(:cluster) do
    isnamevar
  end

  newparam(:cell) do
    

  end

  newparam(:scope) do
    desc <<-EOT
    The scope to manage the JDBC Datasource at.
    Valid values are: node, server, cell, or cluster
    EOT
    validate do |value|
      unless value =~ /^(node|server|cell|cluster)$/
        raise ArgumentError 'scope must be one of "node", "server", "cell", or "cluster"'
      end
    end
  end

  newproperty(:jdbc_provider) do
    desc <<-EOT
    The name of the JDBC Provider to use.
    EOT
  end

  newproperty(:jndi_name) do
    desc <<-EOT
    The JNDI name.
    This corresponds to the wsadmin argument '-jndiName'
    Example: 'jdbc/foo'
    EOT

  end

  newproperty(:data_store_helper_class) do
    desc <<-EOT
    Example: 'com.ibm.websphere.rsadapter.Oracle11gDataStoreHelper'
    EOT
  end

  newparam(:container_managed_persistence) do
    desc <<-EOT
    Use this data source in container managed persistence (CMP)
    Boolean: true or false
    EOT
    # newvalue :true
    # newvalue :false
    defaultto true
  end

  newproperty(:url) do
    desc <<-EOT
    JDBC URL for Oracle providers.
    This is only relevant when the 'data_store_helper_class' is:
      'com.ibm.websphere.rsadapter.Oracle11gDataStoreHelper'
    Example: 'jdbc:oracle:thin:@//localhost:1521/sample'
    EOT
  end

  newproperty(:properties) do
  end

  newproperty(:auth_data_alias) do
  end

  # newproperty(:datasource_helper_classname) do
  # end
  newproperty(:description) do
  end
  newproperty(:xa_recovery_auth_alias) do
  end

  #ConnectionPool
  newproperty(:connection_timeout) do
  end
  newproperty(:max_connections) do
  end
  newproperty(:min_connections) do
  end
  newproperty(:reap_time) do
  end
  newproperty(:aged_timeout) do
  end


  newproperty(:statement_cache_size) do
  end

  newparam(:description) do
    desc <<-EOT
    A description for the data source
    EOT
  end

  newparam(:db2_driver) do
    desc <<-EOT
    The driver for DB2.
    This only applies when the 'data_store_helper_class' is
    'com.ibm.websphere.rsadapter.DB2UniversalDataStoreHelper'
    EOT
  end

  newparam(:database) do
    desc <<-EOT
    The database name for DB2 and Microsoft SQL Server.
    This is only relevant when the 'data_store_helper_class' is one of:
      'com.ibm.websphere.rsadapter.DB2UniversalDataStoreHelper'
      'com.ibm.websphere.rsadapter.MicrosoftSQLServerDataStoreHelper'
    EOT
  end

  newparam(:db_server) do
    desc <<-EOT
    The database server address.
    This is only relevant when the 'data_store_helper_class' is one of:
      'com.ibm.websphere.rsadapter.DB2UniversalDataStoreHelper'
      'com.ibm.websphere.rsadapter.MicrosoftSQLServerDataStoreHelper'
    EOT
  end

  newparam(:db_port) do
    desc <<-EOT
    The database server port.
    This is only relevant when the 'data_store_helper_class' is one of:
      'com.ibm.websphere.rsadapter.DB2UniversalDataStoreHelper'
      'com.ibm.websphere.rsadapter.MicrosoftSQLServerDataStoreHelper'
    EOT
  end

  newparam(:component_managed_auth_alias) do

  end

  newparam(:wsadmin_user) do
    desc "The username for wsadmin authentication"
  end

  newparam(:wsadmin_pass) do
    desc "The password for wsadmin authentication"
  end
end
