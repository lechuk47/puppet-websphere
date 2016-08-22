require 'pathname'

Puppet::Type.newtype(:websphere_cluster) do

  @doc = "Manages the creation or removal of WebSphere server clusters."

  ensurable

  newparam(:dmgr_profile) do
    desc <<-EOT
      Required. The name of the DMGR profile to create this application server
      under.

      Examples: `PROFILE_DMGR_01` or `dmgrProfile01`
    EOT

    validate do |value|
      unless value =~ /^[-0-9A-Za-z._]+$/
        fail("Invalid dmgr_profile #{value}")
      end
    end
  end

  newparam(:name) do
    isnamevar

    desc "The name of the cluster to manage. Defaults to the resource title."

    validate do |value|
      unless value =~ /^[-0-9A-Za-z._]+$/
        fail("Invalid name #{value}")
      end
    end
  end

  newparam(:profile_base) do
    desc <<-EOT
      Required. The full path to the profiles directory where the
      `dmgr_profile` can be found.  The IBM default is
      `/opt/IBM/WebSphere/AppServer/profiles`
    EOT

    validate do |value|
      fail("Invalid profile_base #{value}") unless Pathname.new(value).absolute?
    end
  end
  newparam(:user) do
    defaultto 'root'

    desc <<-EOT
      Optional. The user to run the `wsadmin` command as. Defaults to "root"
    EOT

    validate do |value|
      unless value =~ /^[-0-9A-Za-z._]+$/
        fail("Invalid user #{value}")
      end
    end
  end

  newparam(:wsadmin_user) do
    desc <<-EOT
      Optional. The username for `wsadmin` authentication if security is
      enabled.
    EOT
  end

  newparam(:wsadmin_pass) do
    desc <<-EOT
      Optional. The password for `wsadmin` authentication if security is
      enabled.
    EOT
  end

end

