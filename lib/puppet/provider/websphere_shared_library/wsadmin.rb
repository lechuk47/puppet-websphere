# Provider to modify WebSphere Environment Variables
#
# This is pretty ugly.  We execute their stupid 'wsadmin' tool to query and
# make changes.  That interprets Jython, which is whitespace sensitive.
# That means we have a bunch of heredocs to provide our commands for it.
require 'puppet/provider/websphere_helper'

Puppet::Type.type(:websphere_shared_library).provide(:wsadmin, :parent => Puppet::Provider::Websphere_Helper) do


  mk_resource_methods

  def scope(what)
    file = resource[:profile_base] + '/' + resource[:profile]
    case resource[:scope]
      when 'cell'
        query = '/Cell:' + "#{resource[:cell]}"
        mod   = 'cells/' + "#{resource[:cell]}"
        file  += '/config/cells/' + resource[:cell] + '/libraries.xml'
      when 'cluster'
        query = '/Cell:' + "#{resource[:cell]}" + '/ServerCluster:' + "#{resource[:cluster]}"
        mod   = 'cells/' + "#{resource[:cell]}" + '/clusters/' + "#{resource[:cluster]}"
        file  += '/config/cells/' + resource[:cell] + '/clusters/'  + resource[:cluster] + '/libraries.xml'
      when 'node'
        self.debug("NODE")
        query = '/Cell:' + "#{resource[:cell]}" + '/Node:' + "#{resource[:nodename]}"
        mod   = 'cells/' + "#{resource[:cell]}" + '/nodes/' + "#{resource[:nodename]}"
        file  += '/config/cells/' + resource[:cell] + '/nodes/'  + resource[:nodename] + '/libraries.xml'
      when 'server'
        query = '/Cell:' + "#{resource[:cell]}" + '/Node:' + "#{resource[:nodename]}" + '/Server:' + "#{resource[:server]}"
        mod   = 'cells/' + "#{resource[:cell]}" + '/nodes/' + "#{resource[:nodename]}" + '/servers/' + "#{resource[:server]}"
        file  += '/config/cells/' + resource[:cell] + '/nodes/'  + resource[:nodename] + '/servers/' + resource[:server] + '/libraries.xml'
      else
        raise Puppet::Error, "Unknown scope: #{resource[:scope]}"
      end
    self.debug("query -> " + query.to_s)
    self.debug("mod -> " + mod.to_s)
    self.debug("file -> " + file.to_s)
    case what
    when 'query'
      query
    when 'mod'
      mod
    when 'file'
      file
    else
      self.debug "Invalid scope request"
    end
  end

  def initialize(*args)
    super(*args)
    @modifications = Hash.new
  end

  def create
    self.debug("shared_library creation not implemented yet")
  end

  def destroy
    self.debug("shared_library destroy not implemented yet")
  end


  def self.prefetch(resources)
    # Get resources from the catalog insted of resources param when composite namevars are used. 
    catalog = resources.values.first.catalog
    instances.each do |prov|
      resource = catalog.resources.select { |el| el.title.to_s == prov.name }.first
      unless resource.nil?
        self.debug("Resource prefetched -> " + prov.name)
        resource.provider = prov
      end
    end
  end


  def self.instances()
    arr = []
    self.configuration_files('/*/config/cells/**/libraries.xml').each do |f|
       titlepart = ""
       case f
       when   /\/([-0-9A-Za-z._]+)\/config\/cells\/[-0-9A-Za-z._]+\/libraries.xml/ then
              titlepart = $1 + ":"
          when /\/([-0-9A-Za-z._]+)\/config\/cells\/[-0-9A-Za-z._]+\/nodes\/([-0-9A-Za-z._]+)\/libraries.xml/ then
              titlepart = $1 + ":node:" + $2 + ":"
          when /\/([-0-9A-Za-z._]+)\/config\/cells\/[-0-9A-Za-z._]+\/clusters\/([-0-9A-Za-z._]+)\/libraries.xml/ then
              titlepart = $1 + ":cluster:" + $2 + ":"
          when /\/([-0-9A-Za-z._]+)\/config\/cells\/[-0-9A-Za-z._]+\/nodes\/([-0-9A-Za-z._]+)\/servers\/([-0-9A-Za-z._]+)\/libraries.xml/ then
              titlepart = $1 + ":server:" + $2 + ":" + $3 + ":"
        end

        doc = self.get_rexml_doc( f )
        doc.root.elements.each('libraries:Library') do |el|
            obj = {}
            obj[:ensure]                = :present
            obj[:name]                  = titlepart + el.attributes["name"]
            obj[:classpath]             = el.elements.collect{ |v| v.text }
            obj[:isolated_class_loader] = el.attributes["isolatedClassLoader"]
            obj[:description]           = el.attributes["description"]
            arr.push(new(obj))
        end
      end
      arr
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def shared_library_name=(val)
    @modifications["name"] = val.to_s
  end


  def classpath=(val)
    @modifications["classPath"] = val.join(";").gsub("$", "\$")
  end

  def description=(val)
    @modifications['description'] = val
  end

  def isolated_class_loader=(val)
    @modifications['isolatedClassLoader'] = val.to_s
  end

  def flush
    self.debug("Flushing ")
      self.debug(@modifications)
    unless @modifications.empty?
      str = "["
      @modifications.each do |k,v|
        str += "[ #{k} \"#{v}\" ]"
      end
      str += "]"
      ## There's a bug with some versions of websphere assigning values to the classpath of a shared library via scripting.
      ## depending on the kind of the modification, some values are appended to the end of the string instead of modify the string.
      ## IN case of a classpath modification, I solve the problem removing the classpath value before the modification.
      classpathfix = ""
      if @modifications.key?('classPath') then
        classpathfix = "AdminConfig.modify(obj, '[[classPath \"\"]]')"
      end

      self.debug("Flushing modifications")
      cmd = <<-END
import sys
try:
  id = AdminConfig.getid("#{scope('query')}")
  obj = [ obj for obj in AdminConfig.list("Library",  id).split("\\n") if AdminConfig.showAttribute(obj, 'name') == "#{resource[:name]}"][0]
  #{classpathfix}
  AdminConfig.modify(obj, '#{str}')
  AdminConfig.save()
  print "OK"
except:
  print sys.exc_info()[0:]
  print "KO"
END
      self.debug(cmd)
      result = wsadmin(:file => cmd, :user => "root", :failonfail => false)
      if result !~ /OK/
        raise Puppet::Error, result
      else
        self.debug("Changes flushed OK")
      end
  end
end

end
