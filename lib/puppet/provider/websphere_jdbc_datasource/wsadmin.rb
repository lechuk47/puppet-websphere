require 'puppet/provider/websphere_helper'

Puppet::Type.type(:websphere_jdbc_datasource).provide(:wsadmin, :parent => Puppet::Provider::Websphere_Helper) do

  mk_resource_methods

  def initialize(*args)
    super(*args)
    # Hash to store DataSource object modifications
    @modifications       = Hash.new
    # Hash to store DataSource's ConnectionPool object modifications
    @modifications_cp    = Hash.new
    # Hash to store DataSorce Properties
    @modifications_props = Hash.new
  end

  def scope (what)
    case resource[:scope]
    when 'cell'
      mod_path = "Cell=#{resource[:cell]}"
      get      = "Cell:#{resource[:cell]}"
      path     = "cells/#{resource[:cell]}"
      query    = "/Cell:#{resource[:cell]}/"
    when 'server'
      mod_path = "Cell=#{resource[:cell]},Server=#{resource[:server]}"
      get      = "Cell:#{resource[:cell]}/Node:#{resource[:nodename]}/Server:#{resource[:server]}"
      path     = "cells/#{resource[:cell]}/nodes/#{resource[:nodename]}/servers/#{resource[:server]}"
      query    = "/Node:#{resource[:nodename]}/Server:#{resource[:server]}/"
    when 'cluster'
      mod_path = "Cluster=#{resource[:cluster]}"
      get      = "Cell:#{resource[:cell]}/ServerCluster:#{resource[:cluster]}"
      path     = "cells/#{resource[:cell]}/clusters/#{resource[:cluster]}"
      query    = "/ServerCluster:#{resource[:cluster]}/"
    when 'node'
      mod_path = "Node=#{resource[:nodename]}"
      get      = "Cell:#{resource[:cell]}/Node:#{resource[:nodename]}"
      path     = "cells/#{resource[:cell]}/nodes/#{resource[:nodename]}"
      query    = "/Node:#{resource[:nodename]}/"
    end

    case what
    when 'mod'
      return mod_path
    when 'get'
      return get
    when 'path'
      return path
    when 'query'
      return query
    end
  end

  def config_props
    case resource[:data_store_helper_class]
    when 'com.ibm.websphere.rsadapter.DB2UniversalDataStoreHelper'
      configprop = "[[databaseName java.lang.String #{resource[:database]}] "
      configprop += "[driverType java.lang.Integer #{resource[:db2_driver]}] "
      configprop += "[serverName java.lang.String #{resource[:db_server]}] "
      configprop += "[portNumber java.lang.Integer #{resource[:db_port]}]]"
    when 'com.ibm.websphere.rsadapter.MicrosoftSQLServerDataStoreHelper'
      configprop = "[[databaseName java.lang.String #{resource[:database]}] "
      configprop += "[portNumber java.lang.Integer #{resource[:db_port]}] "
      configprop += "[serverName java.lang.String #{resource[:db_server]}]]"
    when 'com.ibm.websphere.rsadapter.Oracle11gDataStoreHelper'
      configprop = "[[URL java.lang.String #{resource[:url]}]]"
    else
      raise Puppet::Error, "Can't deal withh #{resource[:data_store_helper_class]}"
    end
    return configprop
  end


  def self.prefetch(resources)
    # Prefetch does not seem to work with composite namevars. The resource's hash keys are the name param of the instance.
    # Getting the resources from the catalog object solves this problem
    catalog = resources.values.first.catalog
    typeclass = resources.values.first.class
    instances.each do |prov|
      resource = catalog.resources.select { |el| el.title.to_s == prov.name && el.class == typeclass}.first
      unless resource.nil?
        self.debug("Resource prefetched -> " + prov.name)
        resource.provider = prov
      end
    end
  end


  def self.instances
    self.debug(__method__)
    arr = []
    self.resources_xml_files.each do |resources|
      titlepart = ""
      cell = ""
      case resources
      when /\/([-0-9A-Za-z._]+)\/config\/cells\/([-0-9A-Za-z._]+)\/resources\.xml/ then
             titlepart = $1 + ":"
             cell = $2
         when /\/([-0-9A-Za-z._]+)\/config\/cells\/([-0-9A-Za-z._]+)\/nodes\/([-0-9A-Za-z._]+)\/resources\.xml/ then
             titlepart = $1 + ":node:" + $3 + ":"
             cell = $2
         when /\/([-0-9A-Za-z._]+)\/config\/cells\/([-0-9A-Za-z._]+)\/clusters\/([-0-9A-Za-z._]+)\/resources\.xml/ then
             titlepart = $1 + ":cluster:" + $3 + ":"
             cell = $2
         when /\/([-0-9A-Za-z._]+)\/config\/cells\/([-0-9A-Za-z._]+)\/nodes\/([-0-9A-Za-z._]+)\/servers\/([-0-9A-Za-z._]+)\/resources\.xml/ then
             titlepart = $1 + ":server:" + $3 + ":" + $4 + ":"
             cell = $2
         else
            # Ignore application deployment resources files.
            next
       end

      # Filter resources file to get the JDBC part only. In certain instalations of websphere there is
      # a lot of non-utf8 junk in this files.
      f = File.open( resources )
      ff = Tempfile.new('resources_')
      ok = false
      f.each_line do |line|
        ok = true if line =~ /<resources.jdbc:JDBCProvider.*/
        ff.puts line if ok == true || $. < 3
        ok = false if line =~ /<\/resources.jdbc:JDBCProvider>/
      end
      ff.puts "</xmi:XMI>"
      ff.rewind
      f.close()
      doc = REXML::Document.new( ff )
      ff.close()
      doc.root.elements.each("resources.jdbc:JDBCProvider") do |r|
        providerName = r.attributes["name"]
        r.elements.each("factories") do |f|
          obj = {}
          obj[:ensure]                      = :present
          obj[:name]                        = titlepart + f.attributes["name"]
          obj[:jndi_name]                   = f.attributes["jndiName"]
          obj[:statement_cache_size]        = f.attributes["statementCacheSize"]
          unless f.attributes["authDataAlias"] == nil
            obj[:auth_data_alias]             = "#{cell}:#{f.attributes["authDataAlias"]}"
          end
          unless f.attributes["xaRecoveryAuthAlias"] == nil
            obj[:xa_recovery_auth_alias]      = "#{cell}:#{f.attributes["xaRecoveryAuthAlias"]}"
          end
          obj[:description]                 = f.attributes["description"]
          obj[:data_store_helper_class]     = f.attributes["datasourceHelperClassname"]
          obj[:jdbc_provider]               = providerName

          #Get all the resourceProperties
          props = {}
          f.elements.each("propertySet/resourceProperties") do |rp|
            props[rp.attributes["name"]] = rp.attributes["value"] if rp.attributes["value"] != ""
          end
          #For now I just put the url property
          obj[:url] = props["URL"]

          cp = f.elements["connectionPool"]
          obj[:connection_timeout]  = cp.attributes["connectionTimeout"]
          obj[:max_connections]     = cp.attributes["maxConnections"]
          obj[:min_connections]     = cp.attributes["minConnections"]
          obj[:reap_time]           = cp.attributes["reapTime"]
          obj[:aged_timeout]        = cp.attributes["agedTimeout"]

          arr.push(new(obj))
        end
      end
    end
    arr
end


  def exists?
   @property_hash[:ensure] == :present
  end

  def url=(val)
    @modifications_props["URL"] = val
  end

  def description=(val)
    @modifications["description"] = val
  end

  def max_connections=(val)
    @modifications_cp["maxConnections"] = val
  end

  def min_connections=(val)
    @modifications_cp["minConnections"] = val
  end


  def str_modifications()
    unless @modifications.empty?
      str_modifications = "   AdminConfig.modify(obj, '[" + @modifications.map{|k,v| "[#{k} \"#{v}\"]"}.join(" ") + "]')"
    end
  end

  def str_modifications_cp()
    unless @modifications_cp.empty?
      str_modifications_cp = <<-END
   objCp = AdminConfig.showAttribute(obj, 'connectionPool')
   AdminConfig.modify(objCp, '[#{@modifications_cp.map{|k,v| "[#{k} \"#{v}\"]"}.join(" ")}]')
END
    end
  end

  def str_modifications_props()
    unless @modifications_props.empty?
      str_modifications_props =  <<-END
   dict = { #{@modifications_props.map{|k,v| "\"#{k}\":\"#{v}\""}.join(" ") } }
   props = AdminConfig.showAttribute( AdminConfig.showAttribute(obj, 'propertySet') , 'resourceProperties')[1:-1].split(" ")
   for prop in props:
      name = AdminConfig.showAttribute(prop, 'name')
      if dict.has_key(name):
         AdminConfig.modify(prop, "[[value '%s']]" % (dict[name]) )
END
    end
  end

  def xa_recovery_auth_alias=(val)
    @modifications['xaRecoveryAuthAlias'] = val.split(":")[-1]
  end

  def auth_data_alias=(val)
    @modifications['authDataAlias'] = val.split(":")[-1]
  end



  def create
    self.debug(__method__)
    self.debug(resource[:profile])
    resource.class.validproperties.each do |property|
      if value = resource.should(property)
        @property_hash[property] = value
      end
    end

    @property_hash[:ensure] = :absent

    currentvalues = @resource.retrieve_resource
    self.debug(currentvalues)
    oos = @resource.send(:properties).find_all do |prop|
      unless currentvalues.include?(prop)
        raise Puppet::DevError, "Parent has property %s but it doesn't appear in the current values", [prop.name]
      end
      if prop.name == :ensure
        false
      else
        ! prop.safe_insync?( currentvalues[prop] )
      end
    end.each { |prop| prop.sync }
      if resource[:jdbc_provider] == "Oracle JDBC Driver (XA)"
        xa_res = "-xaRecoveryAuthAlias #{resource[:xa_recovery_auth_alias].split(":")[-1]} "
      end
      cmd = <<-EOT
try:
   provider = AdminConfig.getid( '/#{scope('get')}/JDBCProvider:#{resource[:jdbc_provider]}/' )
   obj = AdminTask.createDatasource(provider, '[-name "#{resource[:name]}" \
-jndiName #{resource[:jndi_name]} \
-dataStoreHelperClassName #{resource[:data_store_helper_class]} \
-componentManagedAuthenticationAlias #{resource[:auth_data_alias].split(":")[-1]} #{xa_res}\
-configureResourceProperties #{config_props} \
-description "#{resource[:description]}" ]')
#{str_modifications_cp}
   AdminConfig.save()
   print "OK"
except:
   print "KO"
   print sys.exc_info()[0]
   print sys.exc_info()[1]
#{sync_node}
EOT
    self.debug "Creating JDBC Datasource with:\n#{cmd}"
    result = wsadmin(:file => cmd, :user => "root", :failonfail => false)
    self.debug "Result:\n#{result}"
    if result !~ /OK/
      raise Puppet::Error, result
    end

    # Empty hashes to prevent flushing
    @modifications = {}
    @modifications_cp = {}
    @modifications_props = {}

  end

  def destroy
    # AdminTask.deleteJDBCProvider('(cells/CELL_01|resources.xml#JDBCProvider_1422560538842)')
    self.debug "Removal of JDBC Providers is not yet implemented"
  end

  def flush
    self.debug("Flushing ")
    if @modifications.empty? && @modifications_cp.empty? && @modifications_props.empty?
      self.debug("ALL EMPTY")
      return
    end

   self.debug("Flushing modifications")
   cmd = <<-END
import sys
try:
   id = AdminConfig.getid("#{scope('query')}")
   obj = [ obj for obj in AdminConfig.list("DataSource",  id).split("\\n") if AdminConfig.showAttribute(obj, 'name') == "#{resource[:name]}"][0]
#{str_modifications}
#{str_modifications_cp}
#{str_modifications_props}
   AdminConfig.save()
   print "OK"
except:
   print sys.exc_info()[0:]
   print "KO"
#{sync_node}
END
  self.debug(cmd)
  result = wsadmin(:file => cmd, :user => "root", :failonfail => false)
  #result = "OK"
  if result !~ /OK/
    raise Puppet::Error, result
  else
    self.debug("Changes flushed OK")
  end

  end
end
