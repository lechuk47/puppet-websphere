# Provider to Manage JVM Custom Properties
#

require 'puppet/provider/websphere_helper'
#require 'rexml/document'
#include REXML

Puppet::Type.type(:websphere_server_environment_entry).provide(:wsadmin, :parent => Puppet::Provider::Websphere_Helper) do

  mk_resource_methods

  def initialize(*args)
    super(*args)
    @element = Hash.new
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
    self.debug("selfinstances")
    arr = []
    self.server_xml_files.each do |server_xml|
        parts    = server_xml.split("/")
        profile  = parts[-9]
        nodename = parts[-4]
        server   = parts[-2]
        self.get_elements_hash(  server_xml,
                                            'processDefinitions[@xmi:type="processexec:JavaProcessDef"]/environment',
                                            'name').each do |k,v|
          obj = {}
          obj[:ensure]  = :present
          obj[:name]    = "#{profile}:#{nodename}:#{server}:#{v['name']}"
          obj[:value]   = v["value"]
          arr.push(new(obj))
        end
    end
    arr
  end

  # def self.instances
  #   arr = []
  #   self.server_xml_files.each do |server_xml|
  #     parts    = server_xml.split("/")
  #     nodename = parts[-4]
  #     server   = parts[-2]
  #     profile  = parts[-9]
  #     prefix = "#{profile}:#{nodename}:#{server}:"
  #     elements = self.get_elements_hash(server_xml,'processDefinitions[@xmi:type="processexec:JavaProcessDef"]', 'environment')
  #     elements.each do |k,v|
  #       v[:xmlfile] = server_xml
  #       v[:ensure]  = :present
  #       v[:name]    = "#{profile}:#{nodename}:#{server}:#{v['name']}"
  #       arr.push(new(v))
  #     end

        # doc = REXML::Document.new(File.open(f))
        # doc.root.elements['processDefinitions[@xmi:type="processexec:JavaProcessDef"]'].elements.each("environment") do |prop|
        #   if prop.class == REXML::Element
        #     obj = {}
        #     obj[:name]    = "#{profile}:#{nodename}:#{server}:#{prop.attributes["name"]}"
        #     obj[:ensure]  = :present
        #     obj[:entry]   = prop.attributes["name"]
        #     obj[:value]   = prop.attributes["value"]
        #     ###
        #     obj[:xml_file] = f
        #     obj[:profile_base]  = profile_path
        #     obj[:profile]       = profile
        #     obj[:cell]          = cell
        #     obj[:nodename]      = nodename
        #     obj[:server]        = server
        #     arr.push(new(obj))
        # end
        # end
  #   end
  #   arr
  # end


  def exists?

    # I need the params of the resource to find the server_xml file. but the params of the type are not there with puppet resource
    # See self.instances method
    # This should be improved
    # if resource[:profile_base].nil?
    #     server_xml = @property_hash[:xmlfile]
    #   else
    #     server_xml = "#{resource[:profile_base]}/#{resource[:profile]}/config/cells/#{resource[:cell]}/nodes/#{resource[:nodename]}/servers/#{resource[:server]}/server.xml"
    # end
    #
    # elements = self.class.get_elements_hash(server_xml,'processDefinitions[@xmi:type="processexec:JavaProcessDef"]', 'environment')
    # name = resource[:name].split(":")[-1]
    # if elements.key?( name )
    #   @element = elements[ name ]
    #   true
    # else
    #   false
    # end
    @property_hash[:ensure] == :present
  end


  #   xml_data = File.open(server_xml)
  #   doc = REXML::Document.new(xml_data)
  #   xml_data.close()
  #   found = false
  #   doc.root.elements['processDefinitions[@xmi:type="processexec:JavaProcessDef"]'].elements.each("environment") do |prop|
  #     if prop.class == REXML::Element and prop.attributes["name"] == resource[:name].split(":")[-1]
  #       @element['value']       = prop.attributes['value']
  #       @element['description'] = prop.attributes['description']
  #       found = true
  #     end
  #   end
  #   self.debug("found -> " + found.to_s)
  #   found
  # end

  # def value
  #   @element['value']
  # end

  # def entry=(val)
  #   @modifications['name'] = val
  # end

  def value=(val)
    @modifications['value'] = val
  end

  # def entry=(val)
  #   @modifications['name'] = val
  # end

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
