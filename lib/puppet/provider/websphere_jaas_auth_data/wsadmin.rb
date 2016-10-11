# Provider to Manage JVM Custom Properties
#

require 'puppet/provider/websphere_helper'

Puppet::Type.type(:websphere_jaas_auth_data).provide(:wsadmin, :parent => Puppet::Provider::Websphere_Helper) do

  mk_resource_methods

  def initialize(*args)
    super(*args)
    # Attach all the modifications to modifications hash to flush the resource in one time
    @modifications = Hash.new()
  end

  def self.prefetch(resources)
    # Prefetch does not seem to work with composite namevars. The keys of the resources hash are the name param of the instance.
    # It seems that getting the resources from the catalog object it's possible to manage composite namevars in prefetch
    catalog = resources.values.first.catalog
    typeclass = resources.values.first.class
    instances.each do |prov|
      resource = catalog.resources.select { |el| el.title.to_s == prov.name && el.class == typeclass }.first
      unless resource.nil?
        self.debug("Resource prefetched -> " + prov.name)
        resource.provider = prov
      end
    end
  end

  def self.instances
    arr = []
    self.security_file.each do |security|
        parts    = security.split("/")
        profile  = parts[-5]
        self.get_elements_hash(security, 'authDataEntries', 'alias').each do |k,v|
          obj = {}
          obj[:ensure]      = :present
          obj[:name]        = "#{profile}:#{v['alias']}"
          obj[:userid]      = v['userId']
          obj[:password]    = v['password']
          obj[:description] = v['description']
          arr.push(new(obj))
        end
    end
    arr
  end




  def exists?
      @property_hash[:ensure] == :present
    end

  def name=(val)
    self.debug("CHANGE NAME -> " + val)
  end

  def userid=(val)
    @modifications["userId"] = val
  end

  def password=(val)
    @modifications["password"] = val
  end

  def description=(val)
    @modifications["description"] = val
  end

  def create
    self.debug(__method__)
    self.debug(resource[:profile])
    # Check if the property exists first in the dmgr.
    # If the node is not in sync with dmgr it's possible to duplicate properties
    cmd = <<-END
import sys
try:
   security = AdminConfig.getid("/Cell:#{resource[:cell]}/Security:/")
   attrs = [
     [ 'alias', "#{resource[:name]}"],
     [ 'userId', "#{resource[:userid]}"],
     [ 'password', "#{resource[:password]}"],
     [ 'description', "#{resource[:description]}"]
   ]
   AdminConfig.create("JAASAuthData", security, attrs)
   AdminConfig.save()
   print "OK"
except:
  print sys.exc_info()[0]
  print sys.exc_info()[1]
  print "KO"
#{sync_node}
END
    self.debug "Running \n#{cmd}"
    result = wsadmin(:file => cmd, :user => "root", :failonfail => false)
    if result !~ /OK/
          raise Puppet::Error, result
    end
  end


  def destroy
    self.info("destroy method not yet implemented")
  end



  def flush
    unless @modifications.empty?
      str = "["
      @modifications.each do |k,v|
        if k != 'has_changes'
          str += "[ #{k} \"#{v}\" ]"
        end
      end
      str += "]"
      cmd = <<-END
try:
  jaas = [ x for x in AdminConfig.list("JAASAuthData").split("\\n") if AdminConfig.showAttribute(x, 'alias') == "#{resource[:name]}" ][0]
  AdminConfig.modify(jaas, '#{str}')
  AdminConfig.save()
  print "OK"
except:
  print sys.exc_info()[0]
  print sys.exc_info()[1]
  print "KO"
END
      self.debug "Running #{cmd}"
      result = wsadmin(:file => cmd, :user => "root", :failonfail => false)
      if result !~ /OK/
        raise Puppet::Error, result
      end

    end

  end

end
