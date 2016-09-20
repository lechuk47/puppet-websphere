# Provider for managing websphere cluster members.
# This parses the cluster member's "server.xml" to read current status, but
# uses the 'wsadmin' tool to make changes.  We cannot modify the xml data, as
# it's basically read-only.  wsadmin is painfully slow.
#
require 'puppet/provider/websphere_server'

Puppet::Type.type(:websphere_application_server).provide(:websphere_server, :parent => Puppet::Provider::Websphere_Server) do
  mk_resource_methods


  def self.prefetch(resources)
    # Prefetch does not seem to work with composite namevars. The keys of the resources hash are the name param of the instance.
    # Check all the params that conform all the namevars of the resource.
    # namevars -> #profile:nodename:server:name
    instances.each do |prov|
      profile,nodename,name = prov.name.split(":")
      #try to assign the resource by name, if the key exist the if sentence returns true
      if resource = resources[name]
        if resources[name].parameters[:profile].value == profile &&
           resources[name].parameters[:nodename].value == nodename &&
               resource.provider = prov
        end
      end
    end
  end


  def self.instances
    servers = []
    Facter['was_profiles'].value.split(",").each do |profile_path|
      Dir.glob( profile_path + '/*/config/cells/**/server.xml').each do |f|
        clusterName = self.get_process_attribute('clusterName', f)
        isAs = self.get_process_attribute('xmlns:applicationserver', f)
          if clusterName.nil? && isAs != nil
          parts    = f.split("/")
          nodename = parts[-4]
          server   = parts[-2]
          profile  = parts[-9]
          obj = self.build_object("#{profile}:#{nodename}:#{server}", server,  f )
          servers.push(new(obj))
        end
       end
      end
      servers
  end

end
