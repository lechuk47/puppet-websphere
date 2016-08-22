# Provider for managing websphere cluster members.
# This parses the cluster member's "server.xml" to read current status, but
# uses the 'wsadmin' tool to make changes.  We cannot modify the xml data, as
# it's basically read-only.  wsadmin is painfully slow.
#
require 'puppet/provider/websphere_helper'
require 'digest/md5'

Puppet::Type.type(:websphere_server).provide(:wsadmin, :parent => Puppet::Provider::Websphere_Helper) do

  mk_resource_methods

  def initialize(*args)
    super(*args)
    @modifications = ""
  end


  def self.prefetch(resources)
    self.debug("PREFECTH")
    self.debug("KEYS -> " + resources.keys.to_s)
    # Prefetch does not seem to work with composite namevars. The keys of the resources hash are the name param of the instance.
    # Check all the params that conform all the namevars of the resource.
    # namevars -> #profile:nodename:server:name
    instances.each do |prov|
      self.debug("prov.name -> " + prov.name)
      profile,nodename,name = prov.name.split(":")
      #try to assign the resource by name, if the key exist the if sentence returns true
      if resource = resources[name]
        if resources[name].parameters[:profile].value == profile &&
           resources[name].parameters[:nodename].value == nodename &&
               resource.provider = prov
        end
      end
    end
  end

  def self.instances
    self.debug("SELFINSTANCES")
    arr = []
    servers = []
    self.debug("Facter['was_profiles'].value =" + Facter['was_profiles'].value)
    Facter['was_profiles'].value.split(",").each do |profile_path|
      Dir.glob( profile_path + '/*/config/cells/**/server.xml').each do |f|
        parts    = f.split("/")
        nodename = parts[-4]
        server   = parts[-2]
        profile  = parts[-9]
        obj = {}
        obj[:name]                              = "#{profile}:#{nodename}:#{server}"
        obj[:servername]                        = server
        obj[:ensure]                            = :present
        obj[:umask]                             = get_xml_val('processDefinitions','execution', 'umask', '022', f)
        obj[:runas_user]                        = get_xml_val('processDefinitions','execution','runAsUser',nil,f)
        obj[:runas_group]                       = get_xml_val('processDefinitions','execution','runAsGroup',nil,f)
        obj[:jvm_initial_heap_size]             = get_xml_val('processDefinitions','jvmEntries','initialHeapSize',nil,f)
        obj[:jvm_maximum_heap_size]             = get_xml_val('processDefinitions','jvmEntries','maximumHeapSize',nil,f)
        obj[:plugin_props_connect_timeout]      = get_xml_val('components[@xmi:type="applicationserver:ApplicationServer"]', 'webserverPluginSettings', 'ConnectTimeout',nil,f)
        obj[:plugin_props_server_io_timeout]    = get_xml_val('components[@xmi:type="applicationserver:ApplicationServer"]', 'webserverPluginSettings', 'ServerIOTimeout',nil,f)
        obj[:jvm_verbose_garbage_collection]    = get_xml_val('processDefinitions','jvmEntries','verboseModeGarbageCollection',nil,f)
        obj[:jvm_generic_jvm_arguments]         = get_xml_val('processDefinitions','jvmEntries','genericJvmArguments',nil,f)
        obj[:threadpool_webcontainer_min_size]  = get_xml_val('services[@xmi:type="threadpoolmanager:ThreadPoolManager"]','threadPools[@name="WebContainer"]','minimumSize',nil,f)
        obj[:threadpool_webcontainer_max_size]  = get_xml_val('services[@xmi:type="threadpoolmanager:ThreadPoolManager"]','threadPools[@name="WebContainer"]','maximumSize',nil,f)
        arr.push(new(obj))
        end
      end
      arr
  end


  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    self.debug "create"
    # cmd = "\"AdminTask.createClusterMember('[-clusterName "
    # cmd += resource[:cluster] + ' -memberConfig [-memberNode ' + resource[:node]
    # cmd += ' -memberName ' + resource[:name] + ' -memberWeight ' + resource[:weight]
    # cmd += ' -genUniquePorts ' + resource[:gen_unique_ports].to_s
    # cmd += "]]')\""
    #
    # result = wsadmin(:command => cmd, :user => resource[:user], :failonfail => false)
    # unless result =~ /^'#{resource[:name]}\(cells\/#{resource[:cell]}\/clusters\/#{resource[:cluster]}/
    #   msg = "Websphere_cluster_member[#{resource[:name]}]: Failed to "\
    #            + "add cluster member. Make sure the node service is running "\
    #            + "on the remote server. Output: #{result}"
    #   raise Puppet::Error, "Failed to add cluster member. Run with --debug for details. #{msg}"
    #   return false
    # end
    # resource.class.validproperties.each do |property|
    #   if value = resource.should(property)
    #     @property_hash[property] = value
    #   end
    # end
    # return true
  end

  def destroy
    self.debug("destroy")
    # cmd = "\"AdminTask.deleteClusterMember('[-clusterName "
    # cmd += resource[:cluster] + ' -memberNode ' + resource[:node]
    # cmd += ' -memberName ' + resource[:name]
    # cmd += "]')\""
    #
    # wsadmin(:command => cmd, :user => resource[:user])
  end

  def refresh
    flush
  end

  def flush
    self.debug("Flushing websphere_server")
    unless @modifications == ""
      tabbed = ""
      @modifications.split("\n").each do |line|
        tabbed += "   " + line + "\n"
      end
      script = <<END
import sys
try:
#{tabbed}
   AdminConfig.save()
   print "OK"
except:
   print sys.exc_info()[0]
   print sys.exc_info()[1]
   print "KO"
   print sys.exit(1)
END
      self.debug(script)
      result = wsadmin(:file => script)
      print result
    end
  end


######################

   # Helper method for modifying JVM properties
   def jvm_property(name,value)
     cmd = <<-END
AdminTask.setJVMProperties('[-nodeName #{resource[:nodename]} -serverName #{resource[:servername]} -#{name} #{value}]')
     END
     cmd
   end

   # Helper method to change WebspherePluginSettings obj of the server
   def change_plugin_prop(prop, value)
     cmd = <<-END
obj = AdminConfig.list("WebserverPluginSettings", AdminConfig.getid("/Node:#{resource[:nodename]}/Server:#{resource[:servername]}/"))
AdminConfig.modify(obj, '[[ #{prop} "#{value}" ]]')
     END
     cmd
   end
   # Helper method to change process execution properties
   def change_process_execution( prop, value)
     cmd = <<-END
obj = AdminConfig.list("ProcessExecution", AdminConfig.getid("/Node:#{resource[:nodename]}/Server:#{resource[:servername]}/"))
AdminConfig.modify( obj, '[[#{prop} "#{value}"]]')
     END
     cmd
   end


   def plugin_props_connect_timeout=(value)
     @modifications += change_plugin_prop( 'ConnectTimeout', value)
   end

   def plugin_props_server_io_timeout=(value)
     @modifications += change_plugin_prop('ServerIOTimeout', value)
   end


   def umask=(value)
     @modifications += change_process_execution('umask', value)
   end

   def runas_user=(value)
     @modifications += change_process_execution( 'runAsUser', value)
   end

   def runas_group=(value)
     @modifications += change_process_execution( 'runAsGroup', value)
   end


  def jvm_initial_heap_size=(value)
    @modifications += jvm_property('initialHeapSize', resource[:jvm_initial_heap_size])
  end

   def jvm_maximum_heap_size=(value)
     @modifications += jvm_property('maximumHeapSize', resource[:jvm_maximum_heap_size])
   end


#   def jvm_verbose_mode_class=(value)
#     jvm_property('verboseModeClass', resource[:jvm_verbose_mode_class].to_s)
#   end
#

  def jvm_verbose_garbage_collection=(value)
    @modifications += jvm_property('verboseModeGarbageCollection', resource[:jvm_verbose_garbage_collection].to_s)
  end
#
#   def jvm_verbose_mode_jni
#     get_xml_val('processDefinitions','jvmEntries','verboseModeJNI')
#   end
#
#   def jvm_verbose_mode_jni=(value)
#     jvm_property('verboseModeJNI',resource[:jvm_verbose_mode_jni].to_s)
#   end
#
#
#   def jvm_debug_mode
#     get_xml_val('processDefinitions','jvmEntries','debugMode')
#   end
#
#   def jvm_debug_mode=(value)
#     jvm_property('debugMode', resource[:jvm_debug_mode])
#   end
#
#   def jvm_debug_args
#     get_xml_val('processDefinitions','jvmEntries','debugArgs')
#   end
#
#   def jvm_debug_args=(value)
#     jvm_property('debugArgs', "\"#{resource[:jvm_debug_args]}\"")
#   end
#
#   def jvm_run_hprof
#     get_xml_val('processDefinitions','jvmEntries','runHProf')
#   end
#
#   def jvm_run_hprof=(value)
#     jvm_property('runHProf', resource[:jvm_run_hprof].to_s)
#   end
#
#   def jvm_hprof_arguments
#     get_xml_val('processDefinitions','jvmEntries','hprofArguments')
#   end
#
#   def jvm_hprof_arguments=(value)
#     # Might need to quote the value
#     jvm_property('hprofArguments', "\"#{resource[:jvm_hprof_arguments]}\"")
#   end
#
#   def jvm_executable_jar_filename
#     value = get_xml_val('processDefinitions','jvmEntries','executableJarFilename')
#     value = '' if value.to_s == ''
#     value
#   end
#
#   def jvm_executable_jar_filename=(value)
#     # Might need to quote the value
#     jvm_property('executableJarFileName', resource[:jvm_executable_jar_filename])
#   end
#
  # def jvm_generic_jvm_arguments
  #   value = get_xml_val('processDefinitions','jvmEntries','genericJvmArguments')
  #   ## WAS returns an empty string if the jvm args are default
  #   ## self.debug("GET MD5 -> " + Digest::MD5.hexdigest(value).to_s)
  #   value = '' if value.to_s == ''
  #   value
  # end

  def jvm_generic_jvm_arguments=(value)
    # Might need to quote the value
    # Gsub $ to \$ in order to avoid variable substitution
    val = "\\\"" + resource[:jvm_generic_jvm_arguments].join(" ") + "\\\""
    @modifications += jvm_property('genericJvmArguments', val)
  end

#   def jvm_disable_jit
#     get_xml_val('processDefinitions','jvmEntries','disableJIT')
#   end
#
#   def jvm_disable_jit=(value)
#     jvm_property('disableJIT', resource[:jvm_disable_jit].to_s)
#   end
#
#   def total_transaction_timeout
#     get_xml_val(
#       'components[@xmi:type="applicationserver:ApplicationServer"]',
#       'services',
#       'totalTranLifetimeTimeout'
#     )
#   end
#
#   def total_transaction_timeout=(value)
#     cmd = "\"the_id = AdminConfig.list('TransactionService','(cells/"
#     cmd += resource[:cell]
#     cmd += '/nodes/' + resource[:node] + '/servers/'
#     cmd += resource[:name] + "|server.xml)');"
#     cmd += 'AdminConfig.modify(the_id, \'[[totalTranLifetimeTimeout "'
#     cmd += resource[:total_transaction_timeout]
#     cmd += '"]]\')"'
#
#     wsadmin(:command => cmd, :user => resource[:user])
#   end
#
#   def client_inactivity_timeout
#     get_xml_val(
#       'components[@xmi:type="applicationserver:ApplicationServer"]',
#       'services',
#       'clientInactivityTimeout'
#     )
#   end
#
#   def client_inactivity_timeout=(value)
#     cmd = "\"the_id = AdminConfig.list('TransactionService','(cells/"
#     cmd += resource[:cell]
#     cmd += '/nodes/' + resource[:node] + '/servers/'
#     cmd += resource[:name] + "|server.xml)');"
#     cmd += 'AdminConfig.modify(the_id, \'[[clientInactivityTimeout "'
#     cmd += resource[:client_inactivity_timeout]
#     cmd += '"]]\')"'
#
#     wsadmin(:command => cmd, :user => resource[:user])
#   end
#
#   def threadpool_webcontainer_min_size
#     get_xml_val(
#       'services[@xmi:type="threadpoolmanager:ThreadPoolManager"]',
#       'threadPools[@name="WebContainer"]',
#       'minimumSize'
#     )
#   end
#
  # Helper method to change threadpool values. 
  def change_threadpool_value(threadpool, key, value)
    cmd = <<-END
the_id=AdminConfig.getid('/Node:#{resource[:nodename]}/Server:#{resource[:servername]}/')
tpList=AdminConfig.list('ThreadPool', the_id).split("\\n")
for tp in tpList:
  if tp.count('#{threadpool}') == 1:
    tpdest=tp
AdminConfig.modify(tpdest, [['#{key}', "#{value}"]])
END
  cmd
  end

  def threadpool_webcontainer_min_size=(value)
    @modifications += change_threadpool_value('WebContainer', 'minimumSize', value)
  end

  def threadpool_webcontainer_max_size=(value)
    @modifications += change_threadpool_value('WebContainer', 'maximumSize', value)
  end

end
