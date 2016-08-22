require 'pathname'

Puppet::Type.newtype(:websphere_variable) do

  @doc = "This manages a WebSphere environment variable"

  ensurable

  newparam(:variable) do
    desc <<-EOT
    Required. The name of the variable to create/modify/remove.  For example,
    `LOG_ROOT`
    EOT
    validate do |value|
      unless value =~ /^[-0-9A-Za-z._]+$/
        raise ArgumentError, "Invalid variable #{value}"
      end
    end
  end

  newparam(:scope) do
    desc <<-EOT
    The scope for the variable.
    Valid values: cell, cluster, node, or server
    EOT
    validate do |value|
      unless value =~ /^(cell|cluster|node|server)$/
        raise ArgumentError, "Invalid scope #{value}: Must be cell, cluster, node, or server"
      end
    end
  end

  newproperty(:value) do
    desc "The value the variable should be set to."
  end

  newproperty(:description) do
    desc "A description for the variable"
    defaultto 'Managed by Puppet'
  end

  newparam(:server) do
    desc "The server in the scope for this variable"
    validate do |value|
      if value.nil? and self[:scope] == 'server'
        raise ArgumentError, 'server is required when scope is server'
      end
      unless value =~ /^[-0-9A-Za-z._]+$/
        raise ArgumentError, "Invalid server #{value}"
      end
    end
  end

  newparam(:cell) do
    validate do |value|
      if value.nil?
        raise ArgumentError, 'cell is required'
      end
      unless value =~ /^[-0-9A-Za-z._]+$/
        raise ArgumentError, "Invalid cell: #{value}"
      end
    end
  end

  newparam(:node) do
    validate do |value|
      if value.nil? and self[:scope] =~ /(server|cell|node)/
        raise ArgumentError, 'node is required when scope is server, cell, or node'
      end
      unless value =~ /^[-0-9A-Za-z._]+$/
        raise ArgumentError, "Invalid node: #{value}"
      end
    end
  end

  newparam(:cluster) do
    validate do |value|
      if value.nil? and self[:scope] =~ /^cluster$/
        raise ArgumentError, 'cluster is required when scope is cluster'
      end
      unless value =~ /^[-0-9A-Za-z._]+$/
        raise ArgumentError, "Invalid cluster: #{value}"
      end
    end
  end

  newparam(:profile) do
    desc "The profile to run 'wsadmin' under"
    validate do |value|
      if value.nil? and self[:dmgr_profile].nil?
        raise ArgumentError, 'profile is required'
      end

      if value.nil? and self[:dmgr_profile]
        defaultto self[:dmgr_profile]
      end

      unless value =~ /^[-0-9A-Za-z._]+$/
        raise ArgumentError, "Invalid profile #{value}"
      end
    end
  end

  newparam(:dmgr_profile) do
    defaultto { @resource[:profile] }
    desc <<-EOT
    The dmgr profile that this variable should be set under.  Basically, where
    are we finding `wsadmin`

    This is synonomous with the 'profile' parameter.

    Example: dmgrProfile01"
    EOT
  end

  newparam(:name) do
    isnamevar
    desc "The name of the resource"
  end

  newparam(:profile_base) do
    desc "The base directory that profiles are stored.
      Example: /opt/IBM/WebSphere/AppServer/profiles"

    validate do |value|
      unless Pathname.new(value).absolute?
        raise ArgumentError, "Invalid profile_base #{value}"
      end
    end
  end

  newparam(:user) do
    defaultto 'root'
    desc "The user to run 'wsadmin' with"
    validate do |value|
      unless value =~ /^[-0-9A-Za-z._]+$/
        raise ArgumentError, "Invalid user #{value}"
      end
    end
  end

  newparam(:wsadmin_user) do
    desc "The username for wsadmin authentication"
  end

  newparam(:wsadmin_pass) do
    desc "The password for wsadmin authentication"
  end
end
