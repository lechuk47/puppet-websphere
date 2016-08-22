# Common functionality for our websphere cluster providers.
# The methods here are generic enough to be used in multiple providers.
#
require 'rexml/document'
require 'tempfile'

class Puppet::Provider::Websphere_Helper < Puppet::Provider
  ## Build the base 'wsadmin' command that we'll use to make changes.  This
  ## command is derived from whatever the 'profile_base' is (since wsadmin is
  ## profile-specific), the name of the profile, and credentials, if provided.
  ## Can we use the 'commands' method for this?
  def wascmd(file=nil)

    wsadmin_cmd = resource[:profile_base] + '/' + resource[:profile]
    wsadmin_cmd += '/bin/wsadmin.sh -lang jython'
#    wsadmin_cmd = "/opt/WebSphere/AppServer85/bin/wsadmin.sh"
    #wsadmin_cmd = "/opt/IBM/BPM751/bin/wsadmin.sh -lang jython"

    if resource[:wsadmin_user] && resource[:wsadmin_pass]
      wsadmin_cmd += " -username '" + resource[:wsadmin_user] + "'"
      wsadmin_cmd += " -password '" + resource[:wsadmin_pass] + "'"
    end

    if file
      wsadmin_cmd += " -f #{file} "
    else
      wsadmin_cmd += " -c "
    end

    wsadmin_cmd
  end

  ## Method to make changes to the WAS configuration. Pass:
  ## :command => 'some jython stuff'
  ##   The value will be sent to 'wsadmin' with the '-c' argument - evaluating
  ##   the code on the command line.
  ## :file => 'some jython stuff'
  ##   The value will be written to a temporary file and read in by wsadmin
  ##   using the '-f' argument.  This is for more complicated jython that
  ##   doesn't take kindly to being fed in on the command-line.
  def wsadmin(args={})

    if args[:failonfail] == false
      failonfail = false
    else
      failonfail = true
    end

    if args[:user]
      user = args[:user]
    else
      user = 'root'
    end

    if args[:file]
      cmdfile = Tempfile.new('wascmd_')

      ## File needs to be readable by the specified user.
      cmdfile.chmod(0644)
      cmdfile.write(args[:file])
      cmdfile.rewind
      modify = wascmd(cmdfile.path)

    else
      modify = wascmd + args[:command]
    end
  result = nil

    begin
      self.debug "Executing as user #{user}: #{modify}"
      Dir.chdir('/tmp') do
        result = Puppet::Util::Execution.execute(
          modify,
          :failonfail => failonfail,
          :uid => user,
          :combine => true
        )
      end

      result
    rescue
      if failonfail == true
        raise Puppet::Error, "Command failed for #{resource[:name]}: #{result}"
      else
        result
      end
    ensure
      if args[:file]
        cmdfile.close
        cmdfile.unlink
      end
    end
  end

  ## Helper method to query the 'server.xml' file for an attribute.
  ## value.  Ideally, we could have this query any arbitrary xml value with
  ## any depth.  It's rigid and stuck at three levels deep for now.
  def self.get_xml_val(section,element,attribute,missing_value=nil, server_xml=nil)
    self.debug("section -> " + section)
    self.debug("element -> " + element)
    self.debug("attr -> " + attribute)
    unless server_xml
      server_xml = resource[:profile_base] + '/' \
        + resource[:profile] + '/config/cells/' \
        + resource[:cell] + '/nodes/' \
        + resource[:nodename] + '/servers/' \
        + resource[:server] + '/server.xml'
    end

    unless File.exists?(server_xml)
      raise Puppet::Error, "[#{resource[:name]}]: "\
        + "Unable to open server.xml at #{server_xml}. Make sure the profile "\
        + "exists, the node has been federated, a corresponding app instance "\
        + "exists, and the names are correct. Hint:  The DMGR may need to "\
        + "Puppet."
      return false
    end
    xml_data = File.open(server_xml)
    doc = REXML::Document.new(xml_data)
    value = nil
    begin
      value = doc.root.elements[section].elements[element].attributes[attribute]
    rescue Exception => e
        self.debug("Rescued get_xml_val #{e.message}")
        value = missing_value
    end
    xml_data.close()

    unless value
      return missing_value
    end
    self.debug("Resturn -> " + value)
    value.to_s
  end



  # def self.get_xml_val(section,element,attribute,defaultvalue, server_xml=nil)
  #   val = self.get_xml_val(section,element,attribute,server_xml)
  #   if val.nil?
  #     defaultvalue
  #   else
  #     val
  #   end
  # end
=begin

  ## This synchronizes the app node(s) with the dmgr
  def sync_node

    sync_status = "\"the_id = AdminControl.completeObjectName('type=NodeSync,"
    sync_status += "node=" + resource[:node] + ",*');"
    sync_status += "AdminControl.invoke(the_id, 'isNodeSynchronized')\""

    status = wsadmin(
      :command => sync_status,
      :user => resource[:user],
      :failonfail => false
    )
    self.debug "Sync status " + resource[:node] + ": #{status}"

    unless status.include?("'true'")
      if status =~ /Error found in String ""; cannot create ObjectName/
        msg = <<-EOT
        Attempt to synchronize node failed because the node service likely
        isn't running or reachable.  A message about "cannot create ObjectName
        often indicates this.  Ensure that the NODE service is running.
        If the node service isn't running, synchronization will happen once
        it's started.  Node: #{resource[:node]}
        "
        EOT
        self.debug msg
      else
        sync = "\"the_id = AdminControl.completeObjectName('type=NodeSync,"
        sync += "node=" + resource[:node] + ",*');"
        sync += "AdminControl.invoke(the_id, 'sync')\""

        result = wsadmin(
          :command => sync,
          :user => resource[:user],
          :failonfail => false
        )
        self.debug "Sync node " + resource[:node] + ": #{result}"
        result
      end
    end
  end

  def restart_server
    if resource[:server]
cmd = <<-EOT
ns = AdminControl.queryNames('WebSphere:*,type=Server,name=#{resource[:server]}').splitlines()
server = ns[0]
AdminControl.invoke(server, 'restart')
EOT
      self.debug "Restarting #{resource[:node]} #{resource[:server]} with #{cmd}"
      result = wsadmin(:file => cmd, :user => resource[:user], :failonfail => false)
      self.debug "Result: #{result}"
    end

    if resource[:node]
      cmd = "\"na = AdminControl.queryNames('type=NodeAgent,node=#{resource[:node]},*');"
      cmd += "AdminControl.invoke(na,'restart','true true')\""

      self.debug "Restarting node: #{resource[:node]} with #{cmd}"
      result = wsadmin(:command => cmd, :user => resource[:user], :failonfail => false)
      self.debug "Result: #{result}"
    end
  end

  ## We want to make sure we sync the app node with the dmgr when things
  ## change.  This happens automatically anyway, but with a delay.
  def flush
    sync_node
  end
=end
end
