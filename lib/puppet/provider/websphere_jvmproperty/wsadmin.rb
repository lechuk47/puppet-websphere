# Provider to Manage JVM Custom Properties
#

require 'puppet/provider/websphere_helper'

Puppet::Type.type(:websphere_jvmproperty).provide(:wsadmin, :parent => Puppet::Provider::Websphere_Helper) do

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
    instances.each do |prov|
      resource = catalog.resources.select { |el| el.title.to_s == prov.name }.first
      unless resource.nil?
        self.debug("Resource prefetched -> " + prov.name)
        resource.provider = prov
      end
    end
  end

  def self.instances
    arr = []
    self.server_xml_files.each do |server_xml|
        parts    = server_xml.split("/")
        profile  = parts[-9]
        nodename = parts[-4]
        server   = parts[-2]

        self.get_elements_hash(server_xml,
                               'processDefinitions[@xmi:type="processexec:JavaProcessDef"]/jvmEntries/systemProperties',
                               'name' ).each do |k,v|
          obj = {}
          obj[:ensure]  = :present
          obj[:name]    = "#{profile}:#{nodename}:#{server}:#{v['name']}"
          obj[:value]   = v['value']
          arr.push(new(obj))
        end
    end
    arr
  end



  def exists?
      @property_hash[:ensure] == :present
    end



  def value=(val)
    @modifications["value"] = val
  end

  def description=(val)
    @modifications["description"] = val
  end

  def create
    self.debug "create"
    cmd = <<-END
try:
  server=AdminConfig.getid('/Node:#{resource[:nodename]}/Server:#{resource[:server]}')
  jvm=AdminConfig.list("JavaVirtualMachine", server)
  print AdminConfig.create('Property', jvm, '[[name "#{resource[:name]}"] [value "#{resource[:value]}"] [description "#{resource[:description]}"]]')
  AdminConfig.save()
  print "OK"
except:
  print "KO"
END
    self.debug "Running \n#{cmd}"
    result = wsadmin(:file => cmd, :user => "root", :failonfail => false)
    if result !~ /OK/
          raise Puppet::Error, result
    end

end


  def destroy
    self.debug("destroy")
    cmd = <<-END
try:
  jvm=AdminConfig.list("JavaVirtualMachine", AdminConfig.getid('/Node:#{resource[:nodename]}/Server:#{resource[:server]}'))
  propid = ""
  for p in AdminConfig.list("Property", jvm).split("\\n"):
     if AdminConfig.showAttribute(p, 'name') == '#{resource[:name]}':
        propid = p
        break
  AdminConfig.remove(p)
  AdminConfig.save()
  print "OK"
except:
  print "KO"
END
    self.debug "Running \n#{cmd}"
    result = wsadmin(:file => cmd, :user => "root", :failonfail => false)
    if result !~ /OK/
      raise Puppet::Error, result
    end
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
  jvm=AdminConfig.list("JavaVirtualMachine", AdminConfig.getid('/Node:#{resource[:node]}/Server:#{resource[:server]}'))
  propid = ""
  for p in AdminConfig.list("Property", jvm).split("\\n"):
     if AdminConfig.showAttribute(p, 'name') == '#{resource[:name]}':
        propid = p
        break
  AdminConfig.modify(p, '#{str}')
  AdminConfig.save()

  print "OK"
except:
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
