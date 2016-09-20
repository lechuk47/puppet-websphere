require 'pathname'

Puppet::Type.newtype(:websphere_shared_library) do

  @doc = "This manages a WebSphere shared library"

  ensurable

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

  # newproperty (:shared_library_name) do
  #   desc "The name of the shared library"
    # validate do |value|
    #   unless value =~ /^[-0-9A-Za-z._]+$/
    #     raise ArgumentError, "Invalid variable #{value}"
    #   end
    # end
  # end

  newproperty(:classpath, :array_matching => :all) do
    desc "The classpath entries of the shared library"
    def insync?(is)
      # array_matching seems not working here (Maybe due to $ in values)
      # Testing in this way does the job
      is.join(" ") == @should.join(" ")
   end
  end

  newproperty(:description) do
    desc "the description"
    defaultto "Created by Puppet"
  end


  newproperty(:isolated_class_loader, :boolean => true) do
    desc "Use a isolated classloader to load the library"
    defaultto true
  end


  ###PARAMS

  newparam(:name) do
    isnamevar
    desc "The name of the resource"
  end

  newparam(:scope) do
    isnamevar
    desc "The scope of the shared library"
    # validate do |value|
    #   unless value =~ /^(cell|cluster|node|server)$/
    #     raise ArgumentError, "Invalid scope #{value}: Must be cell, cluster, node, or server"
    #   end
    # end
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

  newparam(:cluster) do
    isnamevar
  end

  newparam(:nodename) do
    isnamevar
    # validate do |value|
    #   if value.nil? and self[:scope] =~ /(server|cell|node)/
    #     raise ArgumentError, 'node is required when scope is server, cell, or node'
    #   end
    #   unless value =~ /^[-0-9A-Za-z._]+$/
    #     raise ArgumentError, "Invalid node: #{value}"
    #   end
    # end
  end

  newparam(:server) do
    isnamevar
    desc "The server in the scope for this variable"
    # validate do |value|
    #   if value.nil? and self[:scope] == 'server'
    #     raise ArgumentError, 'server is required when scope is server'
    #   end
    #   unless value =~ /^[-0-9A-Za-z._]+$/
    #     raise ArgumentError, "Invalid server #{value}"
    #   end
    # end
  end


  # Websphere required params (Can't inherit Types oO)
  newparam(:profile_base) do
    desc "The base directory that profiles are stored.
      Example: /opt/IBM/WebSphere/AppServer/profiles"

    validate do |value|
      unless Pathname.new(value).absolute?
        raise ArgumentError, "Invalid profile_base #{value}"
      end
    end
  end

  newparam(:profile) do
    isnamevar
    desc 'The Profile where to find xml configuration files and where to run wsadmin utility.'
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
