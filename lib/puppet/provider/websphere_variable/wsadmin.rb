# Provider to modify WebSphere Environment Variables
#
# This is pretty ugly.  We execute their stupid 'wsadmin' tool to query and
# make changes.  That interprets Jython, which is whitespace sensitive.
# That means we have a bunch of heredocs to provide our commands for it.
require 'puppet/provider/websphere_helper'

Puppet::Type.type(:websphere_variable).provide(:wsadmin, :parent => Puppet::Provider::Websphere_Helper) do

  def scope(what)
    # (cells/CELL_01/nodes/appNode01/servers/AppServer01
    file = resource[:profile_base] + '/' + resource[:dmgr_profile]
    case resource[:scope]
    when 'cell'
      query = '/Cell:' + "#{resource[:cell]}"
      mod   = 'cells/' + "#{resource[:cell]}"
      file  += '/config/cells/' + resource[:cell] + '/variables.xml'
    when 'cluster'
      query = '/Cell:' + "#{resource[:cell]}" + '/ServerCluster:' + "#{resource[:cluster]}"
      mod   = 'cells/' + "#{resource[:cell]}" + '/clusters/' + "#{resource[:cluster]}"
      file  += '/config/cells/' + resource[:cell] + '/clusters/'  + resource[:cluster] + '/variables.xml'
    when 'node'
      query = '/Cell:' + "#{resource[:cell]}" + '/Node:' + "#{resource[:node]}"
      mod   = 'cells/' + "#{resource[:cell]}" + '/nodes/' + "#{resource[:node]}"
      file  += '/config/cells/' + resource[:cell] + '/nodes/'  + resource[:node] + '/variables.xml'
    when 'server'
      query = '/Cell:' + "#{resource[:cell]}" + '/Node:' + "#{resource[:node]}" + '/Server:' + "#{resource[:server]}"
      mod   = 'cells/' + "#{resource[:cell]}" + '/nodes/' + "#{resource[:node]}" + '/servers/' + "#{resource[:server]}"
      file  += '/config/cells/' + resource[:cell] + '/nodes/'  + resource[:node] + '/servers/' + resource[:server] + '/variables.xml'
    else
      raise Puppet::Error, "Unknown scope: #{resource[:scope]}"
    end

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

  def create
cmd = <<-END
# Create for #{resource[:variable]}
scope=AdminConfig.getid('#{scope('query')}/VariableMap:/')
nodeid=AdminConfig.getid('#{scope('query')}/')
# Create a variable map if it doesn't exist
if len(scope) < 1:
  varMapserver = AdminConfig.create('VariableMap', nodeid, [])
AdminConfig.create('VariableSubstitutionEntry', scope, '[[symbolicName "#{resource[:variable]}"] [description "#{resource[:description]}"] [value "#{resource[:value]}"]]')
AdminConfig.save()
END

    self.debug "Running #{cmd}"
    result = wsadmin(:file => cmd, :user => resource[:user], :failonfail => false)

    if result =~ /Invalid parameter value "" for parameter "parent config id" on command "create"/
      ## I'd rather handle this in the Jython, but I'm not sure how.
      ## This usually indicates that the server isn't ready on the DMGR yet -
      ## the DMGR needs to do another Puppet run, probably.
      err = <<-EOT
      Could not create variable: #{resource[:variable]}
      This appears to be due to the remote resource not being available.
      Ensure that all the necessary services have been created and are running
      on this host and the DMGR. If this is the first run, the cluster member
      may need to be created on the DMGR.
      EOT

      if resource[:scope] == 'server'
        err += <<-EOT
        This is a server scoped variable, so make sure the DMGR has created the
        cluster member.  The DMGR may need to run Puppet.
        EOT
      end
      raise Puppet::Error, err

    end

    self.debug result
  end

  def exists?
    unless File.exists?(scope('file'))
      return false
    end

    self.debug "Retrieving value of #{resource[:variable]} from #{scope('file')}"
    doc = REXML::Document.new(File.open(scope('file')))

    path = XPath.first(doc, "//variables:VariableMap/entries[@symbolicName='#{resource[:variable]}']")
    value = XPath.first(path, "@symbolicName") if path

    self.debug "Exists? #{resource[:variable]} is: #{value}"
    unless value
      self.debug "#{resource[:variable]} does not exist for scope #{resource[:scope]}"
      return false
    end

    true

  end

  def value
    if File.exists?(scope('file'))
      doc = REXML::Document.new(File.open(scope('file')))

      path = XPath.first(doc, "//variables:VariableMap/entries[@symbolicName='#{resource[:variable]}']")
      value = XPath.first(path, "@value") if path

      self.debug "Value for #{resource[:variable]} is: #{value}"
      return value.to_s if value
    else
      msg = <<-END
      #{scope('file')} does not exist. This may indicate that the cluster
      member has not yet been realized on the DMGR server. Ensure that the
      DMGR has created the cluster member (run Puppet on it?) and that the
      names are correct (e.g. node name, profile name)
      END
      raise Puppet::Error, msg
    end
    nil
  end

  def value=(val)
cmd = <<-END
# Update value for #{resource[:variable]}
vars = AdminConfig.getid("#{scope('query')}/VariableMap:/VariableSubstitutionEntry:/").splitlines()
for var in vars :
    name = AdminConfig.showAttribute(var, "symbolicName")
    value = AdminConfig.showAttribute(var, "value")
    if (name == "#{resource[:variable]}"):
        AdminConfig.modify(var,[["value", "#{resource[:value]}"]])
AdminConfig.save()
END
    self.debug "Running #{cmd}"
    result = wsadmin(:file => cmd, :user => resource[:user])
    self.debug "result: #{result}"
  end

  def description
    doc = REXML::Document.new(File.open(scope('file')))

    path = XPath.first(doc, "//variables:VariableMap/entries[@symbolicName='#{resource[:variable]}']")
    description = XPath.first(path, "@description") if path

    self.debug "Description for #{resource[:variable]} is: #{description}"
    return description.to_s if description
    nil
  end

  def description=(val)
cmd = <<-END
# Update description for #{resource[:variable]}
vars = AdminConfig.getid("#{scope('query')}/VariableMap:/VariableSubstitutionEntry:/").splitlines()
for var in vars :
    name = AdminConfig.showAttribute(var, "symbolicName")
    value = AdminConfig.showAttribute(var, "description")
    if (name == "#{resource[:variable]}"):
        AdminConfig.modify(var,[["description", "#{resource[:description]}"]])
AdminConfig.save()
END
    self.debug "Running #{cmd}"
    result = wsadmin(:file => cmd, :user => resource[:user])
    self.debug "result: #{result}"
  end


  def destroy
cmd = <<-END
vars=AdminConfig.getid("#{scope('query')}/VariableMap:/VariableSubstitutionEntry:/").splitlines()
for var in vars :
    name = AdminConfig.showAttribute(var, "symbolicName")
    value = AdminConfig.showAttribute(var, "description")
    if (name == "#{resource[:variable]}"):
        AdminConfig.remove(var)
AdminConfig.save()
END

    self.debug "Running #{cmd}"
    result = wsadmin(:file => cmd, :user => resource[:user])
    self.debug result

  end

  def flush
    self.debug 'Initiating node synchronization'
    sync_node
    ## TODO: Need to handle this somehow.
    #restart_server
  end

end
