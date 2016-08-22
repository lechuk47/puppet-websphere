# Provider to modify WebSphere Environment Variables
#
# This is pretty ugly.  We execute their stupid 'wsadmin' tool to query and
# make changes.  That interprets Jython, which is whitespace sensitive.
# That means we have a bunch of heredocs to provide our commands for it.
require 'puppet/provider/websphere_helper'

Puppet::Type.type(:websphere_shared_library).provide(:wsadmin, :parent => Puppet::Provider::Websphere_Helper) do


  def scope(what)
    # (cells/CELL_01/nodes/appNode01/servers/AppServer01
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
    self.debug("CREATE")
# cmd = <<-END
# # Create for #{resource[:variable]}
# scope=AdminConfig.getid('#{scope('query')}/VariableMap:/')
# nodeid=AdminConfig.getid('#{scope('query')}/')
# # Create a variable map if it doesn't exist
# if len(scope) < 1:
#   varMapserver = AdminConfig.create('VariableMap', nodeid, [])
# AdminConfig.create('VariableSubstitutionEntry', scope, '[[symbolicName "#{resource[:variable]}"] [description "#{resource[:description]}"] [value "#{resource[:value]}"]]')
# AdminConfig.save()
# END
#
#     self.debug "Running #{cmd}"
#     result = wsadmin(:file => cmd, :user => resource[:user], :failonfail => false)
#
#     if result =~ /Invalid parameter value "" for parameter "parent config id" on command "create"/
#       ## I'd rather handle this in the Jython, but I'm not sure how.
#       ## This usually indicates that the server isn't ready on the DMGR yet -
#       ## the DMGR needs to do another Puppet run, probably.
#       err = <<-EOT
#       Could not create variable: #{resource[:variable]}
#       This appears to be due to the remote resource not being available.
#       Ensure that all the necessary services have been created and are running
#       on this host and the DMGR. If this is the first run, the cluster member
#       may need to be created on the DMGR.
#       EOT
#
#       if resource[:scope] == 'server'
#         err += <<-EOT
#         This is a server scoped variable, so make sure the DMGR has created the
#         cluster member.  The DMGR may need to run Puppet.
#         EOT
#       end
#       raise Puppet::Error, err
#
#     end
#
#     self.debug result
  end

  # Override method from helper to return 2 level objects from libraries.xml
  def get_xml_val( element, attribute )
    self.debug("element -> " + element)
    self.debug("attr -> " + attribute)

    unless File.exists?( scope('file'))
      raise Puppet::Error, "Websphere_shared_library #{scope('file')} does not exist"
      return false
    end

    xml_data = File.open( scope('file') )
    doc = REXML::Document.new(xml_data)
    begin
      value = doc.root.elements[element].attributes[attribute]
    rescue Exception => e
        self.debug("Rescued get_xml_val #{e.message}")
        value = nil
    end
    xml_data.close()
    unless value
      return nil
    end
    value.to_s
  end

  def exists?
    self.debug("EXISTS")
    f = scope('file')
    self.debug(f)
    unless File.exists?(scope('file'))
      return false
    end

    self.debug "Retrieving value of #{resource[:name]} from #{scope('file')}"
    doc = REXML::Document.new(File.open(scope('file')))
    path =  REXML::XPath.first(doc,"//libraries:Library[@name='#{resource[:name]}']")

    unless path
      self.debug "#{resource[:name]} does not exist for scope #{resource[:scope]}"
      return false
    end

    true

  end


  def name
      get_xml_val("libraries:Library[@name='#{resource[:name]}']", "name")
  end

  def name=(val)
    @modifications["name"] = val.to_s
  end

  def classpath
    if File.exists?( scope('file') )
      f = File.open( scope('file') )
      doc = REXML::Document.new( f )
      arr = doc.root.elements['libraries:Library[@name="IBM_BPM_Process_Server_Shared_Library"]'].elements.collect { |v|
        v.text
      }
      f.close()
      self.debug("A" + arr.join(" ").to_s)
      self.debug("COM" + (arr.join(" ") == resource.should("classpath").join(" ")).to_s)
      self.debug("B" + resource.should("classpath").join(" ").to_s)
      return arr
    else
      msg = <<-END
      #{scope('file')} does not exist.
      END
      raise Puppet::Error, msg
    end
    nil
  end

  def classpath=(val)
    @modifications["classPath"] = val.join(";").gsub("$", "\$")
  end

  def description
    get_xml_val("libraries:Library[@name='#{resource[:name]}']", "description")
  end

  def description=(val)
    @modifications['description'] = val
  end

  def isolated_class_loader
    get_xml_val("libraries:Library[@name='#{resource[:name]}']", "isolatedClassLoader" )
  end

  def isolated_class_loader=(val)
    @modifications['isolatedClassLoader'] = val.to_s
  end

  def destroy
  end

  def flush
    # AdminConfig.modify('(cells/celldev03/nodes/bpmgcast19|libraries.xml#Library_1394533591016)',
    # '[[nativePath ""]
    # [name "IBM_BPM_Process_Server_Shared_Library"]
    # [isolatedClassLoader "false"]
    # [description ""]
    # [classPath "${WAS_INSTALL_ROOT}/BPM/Lombardi/lib/;${WAS_INSTALL_ROOT}/BPM/Lombardi/process-server/lib/procsrv_resources.jar;"]
    # ]')
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
