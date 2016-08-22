# Provider to Manage JVM Custom Properties
#

require 'puppet/provider/websphere_helper'
#require 'rexml/document'
#include REXML

Puppet::Type.type(:websphere_server_environment_entry).provide(:wsadmin, :parent => Puppet::Provider::Websphere_Helper) do

  mk_resource_methods

  def initialize(*args)
    super(*args)
    @modifications = Hash.new
  end


  def create
    self.debug "create"
    cmd = <<-END
try:
  obj=AdminConfig.list("JavaProcessDef", AdminConfig.getid('/Server:#{resource[:server]}') )
  AdminConfig.create('Property', obj, '[[name #{resource[:jvmproperty]}] [value #{resource[:value]}] [description #{resource[:description]}]]')
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

  obj=AdminConfig.list("JavaProcessDef", AdminConfig.getid('/Server:#{resource[:server]}') )
  propid = ""
  for p in AdminConfig.list("Property", obj).split("\\n"):
     if AdminConfig.showAttribute(p, 'name') == '#{resource[:jvmproperty]}':
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
    self.debug("selfinstances")
    self.debug("Facter['was_profiles'].value =" + Facter['was_profiles'].value)
    arr = []
    Facter['was_profiles'].value.split(",").each do |profile_path|
      Dir.glob( profile_path + '/*/config/cells/**/server.xml').each do |f|
        self.debug("F ->" + f)
        parts    = f.split("/")
        nodename = parts[-4]
        server   = parts[-2]
        profile  = parts[-9]
        doc = REXML::Document.new(File.open(f))
        self.debug("before")
        doc.root.elements['processDefinitions[@xmi:type="processexec:JavaProcessDef"]'].elements.each("environment") do |prop|
          self.debug(prop)
          if prop.class == REXML::Element
            obj = {}
            obj[:name]    = "#{profile}:#{nodename}:#{server}:#{prop.attributes["name"]}"
            obj[:ensure]  = :present
            obj[:entry]   = prop.attributes["name"]
            obj[:value]   = prop.attributes["value"]
            arr.push(new(obj))
          end
        end
      end
    end
    arr
  end


  def exists?
    self.debug("exists? ")
    @property_hash[:ensure] == :present
    # unless get_xml_val("processDefinitions[@xmi:type=\"processexec:JavaProcessDef\"]", "environment[@name=\"#{resource[:entry]}\"]", "name")
    #   return false
    # else
    #   return true
    # end
  end

  # def value
  #    self.debug("value")
  #    get_xml_val('processDefinitions[@xmi:type="processexec:JavaProcessDef"]',"environment[@name=\"#{resource[:entry]}\"]", "value" )
  # end

  def value=(val)
    @modifications['value'] = val
  end


  # def entry
  #   self.debug("entry")
  #   get_xml_val('processDefinitions[@xmi:type="processexec:JavaProcessDef"]',"environment[@name=\"#{resource[:entry]}\"]", "name" )
  # end

  def entry=(val)
    @modifications['name'] = val
  end

  def flush
    self.debug("Flushing ")
    self.debug(@modifications)
    unless @modifications.empty?
      str = "["
      @modifications.each do |k,v|
        str += "[ #{k} #{v} ]"
      end
      str = "]"

      self.debug("Flushing modifications")
      cmd = <<-END
try:
  obj = AdminConfig.list("JavaProcessDef", AdminConfig.getid("/Server:#{resource[:server]}/"))
  prop = [p for p in AdminConfig.showAttribute(obj, "environment")[1:-1].split() if AdminConfig.showAttribute(p, 'name') == #{resource[:entry]}][0]
  AdminConfig.modify(prop, "#{str}")
  AdminConfig.save()
  print "OK"
except:
  print "KO"
      END

      result = wsadmin(:file => @modifications )
      if result !~ /OK/
        raise Puppet::Error, result
      else
        self.debug("Changes flushed OK")
      end
    end

  end


end
