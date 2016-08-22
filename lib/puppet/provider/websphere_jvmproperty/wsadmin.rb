# Provider to Manage JVM Custom Properties
#

require 'puppet/provider/websphere_helper'
#require 'rexml/document'
#include REXML

Puppet::Type.type(:websphere_jvmproperty).provide(:wsadmin, :parent => Puppet::Provider::Websphere_Helper) do

  mk_resource_methods

  def initialize(*args)
    super(*args)
    @modifications = Hash.new()
  end

  def self.prefetch(resources)
    self.debug("PREFECTH")
    self.debug("KEYS -> " + resources.keys.to_s)
    # Prefetch does not seem to work with composite namevars. The keys of the resources hash are the name param of the instance.
    # Check all the params that conform all the namevars of the resource.
    # namevars -> #profile:nodename:server:name
    instances.each do |prov|
      self.debug("prov.name -> " + prov.name)
      profile,nodename,server,name = prov.name.split(":")
      #try to assign the resource by name, if the key exist the if sentence returns true
      if resource = resources[name]
        if resources[name].parameters[:profile].value == profile &&
           resources[name].parameters[:nodename].value == nodename &&
           resources[name].parameters[:server].value == server
              resource.provider = prov
        end
      end
    end
 end

  def self.instances
    self.debug("SELFINSTANCES")
    #jvmproperty, value, description
    arr = []
    servers = []
    self.debug("Facter['was_profiles'].value =" + Facter['was_profiles'].value)
    Facter['was_profiles'].value.split(",").each do |profile_path|
      Dir.glob( profile_path + '/*/config/cells/**/server.xml').each do |f|
        parts    = f.split("/")
        nodename = parts[-4]
        server   = parts[-2]
        profile  = parts[-9]
        doc = REXML::Document.new(File.open(f))
        doc.root.elements['processDefinitions[@xmi:type="processexec:JavaProcessDef"]/jvmEntries'].each do |prop|
          if prop.class == REXML::Element
            jvmproperty = {}
            jvmproperty[:name]        = "#{profile}:#{nodename}:#{server}:#{prop.attributes["name"]}"
            jvmproperty[:ensure]      = :present
            jvmproperty[:value]       = prop.attributes["value"]
            jvmproperty[:description] = prop.attributes["description"]
            arr.push(new(jvmproperty))
          end
        end
      end
    end
    arr
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
  jvm=AdminConfig.list("JavaVirtualMachine", AdminConfig.getid('/Node:#{resource[:node]}/Server:#{resource[:server]}'))
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

  def exists?
    self.debug("EXISTS")
    self.debug(@property_hash)
    @property_hash[:ensure] == :present
  end

  def value=(val)
    @modifications["value"] = val
  end

  def description=(val)
    @modifications["description"] = val
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
    self.debug("No changes")
  end
end
