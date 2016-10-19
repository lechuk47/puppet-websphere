require 'pathname'

Puppet::Type.newtype(:websphere_jaas_auth_data) do

  @doc = "This manages a WebSphere jaas auth data elements"

  ensurable

  def self.title_patterns
    [
      [
        /^(.*):(.*)/,
        [
          [:cell, lambda{|x| x}  ],
          [:name, lambda{|x| x} ]
        ]
      ]
    ]
  end

  # newparam(:profile) do
  #   desc 'The Profile where to find xml configuration files and where to run wsadmin utility.'
  # end

  newparam(:name) do
    isnamevar
  end

  # newproperty(:jalias) do
  #   desc "The alias of the jaas auth data entry"
  # end

  newproperty(:userid) do
    desc "The userid of the entry"
  end

  newproperty(:password) do
    desc "The password of the entry"
  end

  newproperty(:description) do
    desc "the Description"
  end

  newparam(:nodename) do
    desc 'Ununsed param here, just for accepting the default hash.'
  end

  newparam(:profile) do
  end
  

  newparam(:cell) do
    isnamevar
    desc "CEll of the Resource"

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

  newparam(:wsadmin_user) do
    desc "The username for wsadmin authentication"
  end

  newparam(:wsadmin_pass) do
    desc "The password for wsadmin authentication"
  end
end
