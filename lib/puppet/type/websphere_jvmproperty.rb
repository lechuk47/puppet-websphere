require 'pathname'

Puppet::Type.newtype(:websphere_jvmproperty) do

  @doc = "This manages a WebSphere server jvmproperty"

  ensurable

  # newproperty(:jvmproperty) do
  #   desc <<-EOT
  #   Required. The name of the variable to create/modify/remove.  For example,
  #   `LOG_ROOT`
  #   EOT
  #   validate do |value|
  #     unless value =~ /^[-0-9A-Za-z._]+$/
  #       raise ArgumentError, "Invalid variable #{value}"
  #     end
  #   end
  # end

  newproperty(:value) do
    desc "The value the variable should be set to."
  end

  newproperty(:description) do
    desc "the description"
    #defaultto "Created by Puppet"
  end

#PARAMS
def self.title_patterns
  [
    [
      /^(.*):(.*):(.*):(.*)/,
      [
        [:profile, lambda{|x| x}  ],
        [:nodename, lambda{|x| x} ],
        [:server, lambda{|x| x} ],
        [:name, lambda{|x| x} ]
      ]
    ]
  ]
end


  # newparam(:name) do
  #   desc "The name of the resource"
  # end

  newparam(:name) do
    isnamevar
    desc "The name of the resource"
  end


  newparam(:server) do
    isnamevar
    desc "The server in the scope for this variable"
    validate do |value|
      # if value.nil? and self[:scope] == 'server'
      #   raise ArgumentError, 'server is required when scope is server'
      # end
      unless value =~ /^[-0-9A-Za-z._]+$/
        raise ArgumentError, "Invalid server #{value}"
      end
    end
  end

  newparam(:profile) do
    isnamevar
    desc 'The Profile where to find xml configuration files and where to run wsadmin utility.'
  end

  newparam(:nodename) do
    isnamevar
    validate do |value|
      if value.nil? and self[:scope] =~ /(server|cell|node)/
        raise ArgumentError, 'node is required when scope is server, cell, or node'
      end
      unless value =~ /^[-0-9A-Za-z._]+$/
        raise ArgumentError, "Invalid node: #{value}"
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

## Websphere required params (Can't inherit Types oO)

  newparam(:profile_base) do
    desc "The base directory that profiles are stored.
      Example: /opt/IBM/WebSphere/AppServer/profiles"

    validate do |value|
      unless Pathname.new(value).absolute?
        raise ArgumentError, "Invalid profile_base #{value}"
      end
    end
  end



  newparam(:wsadmin_user) do
    desc "The username for wsadmin authentication"
  end

  newparam(:wsadmin_pass) do
    desc "The password for wsadmin authentication"
  end

  # newparam(:user) do
  #   defaultto 'root'
  #   desc "The user to run 'wsadmin' with"
  #   validate do |value|
  #     unless value =~ /^[-0-9A-Za-z._]+$/
  #       raise ArgumentError, "Invalid user #{value}"
  #     end
  #   end
  # end
end
