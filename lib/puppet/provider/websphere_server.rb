# Provider for managing websphere cluster members.
# This parses the cluster member's "server.xml" to read current status, but
# uses the 'wsadmin' tool to make changes.  We cannot modify the xml data, as
# it's basically read-only.  wsadmin is painfully slow.
#
require 'puppet/provider/websphere_helper'
require 'rexml/document'
require 'digest/md5'

class Puppet::Provider::Websphere_Server < Puppet::Provider::Websphere_Helper

  def initialize(*args)
    super(*args)
    @modifications = ""
  end

  def self.build_object(title, servername, server_xml )
    unless File.exists?(server_xml)
      raise Puppet::Error, "[#{resource[:name]}]: "
        + "Unable to open server.xml at #{server_xml}. Make sure the profile "\
        + "exists, the node has been federated, a corresponding app instance "\
        + "exists, and the names are correct. Hint:  The DMGR may need to "\
        + "Puppet."
      return false
    end
    xml_data = File.open( server_xml )
    rexml_doc = REXML::Document.new( xml_data )
    obj = {}
    obj[:ensure]                            = :present
    obj[:name]                              = title
    obj[:servername]                        = servername
    obj[:umask]                             = get_xml_val( rexml_doc, ['processDefinitions','execution'], 'umask', '022')
    obj[:runas_user]                        = get_xml_val( rexml_doc, ['processDefinitions','execution'],'runAsUser',nil )
    obj[:runas_group]                       = get_xml_val( rexml_doc, ['processDefinitions','execution'],'runAsGroup',nil)
    obj[:jvm_initial_heap_size]             = get_xml_val( rexml_doc, ['processDefinitions','jvmEntries'],'initialHeapSize',nil)
    obj[:jvm_maximum_heap_size]             = get_xml_val( rexml_doc, ['processDefinitions','jvmEntries'],'maximumHeapSize',nil)
    obj[:plugin_props_connect_timeout]      = get_xml_val( rexml_doc, ['components[@xmi:type="applicationserver:ApplicationServer"]', 'webserverPluginSettings'], 'ConnectTimeout',nil)
    obj[:plugin_props_server_io_timeout]    = get_xml_val( rexml_doc, ['components[@xmi:type="applicationserver:ApplicationServer"]', 'webserverPluginSettings'], 'ServerIOTimeout',nil)
    obj[:jvm_verbose_garbage_collection]    = get_xml_val( rexml_doc, ['processDefinitions','jvmEntries'],'verboseModeGarbageCollection', nil)
    obj[:jvm_generic_jvm_arguments]         = get_xml_val( rexml_doc, ['processDefinitions','jvmEntries'],'genericJvmArguments',nil)
    obj[:threadpool_webcontainer_min_size]  = get_xml_val( rexml_doc, ['services[@xmi:type="threadpoolmanager:ThreadPoolManager"]','threadPools[@name="WebContainer"]'],'minimumSize',nil)
    obj[:threadpool_webcontainer_max_size]  = get_xml_val( rexml_doc, ['services[@xmi:type="threadpoolmanager:ThreadPoolManager"]','threadPools[@name="WebContainer"]'],'maximumSize',nil)
    obj[:sysout_rotation_type]              = get_xml_val( rexml_doc, ["outputStreamRedirect"],'rolloverType',nil)
    obj[:sysout_rotation_hour]              = get_xml_val( rexml_doc, ["outputStreamRedirect"],'baseHour',nil)
    obj[:sysout_rotation_period]            = get_xml_val( rexml_doc, ["outputStreamRedirect"],'rolloverPeriod',nil)
    obj[:sysout_rotation_size]              = get_xml_val( rexml_doc, ["outputStreamRedirect"],'rolloverSize',nil)
    obj[:sysout_rotation_backups]           = get_xml_val( rexml_doc, ["outputStreamRedirect"],'maxNumberOfBackupFiles',nil)
    obj[:syserr_rotation_type]              = get_xml_val( rexml_doc, ["errorStreamRedirect"],'rolloverType',nil)
    obj[:syserr_rotation_hour]              = get_xml_val( rexml_doc, ["errorStreamRedirect"],'baseHour',nil)
    obj[:syserr_rotation_period]            = get_xml_val( rexml_doc, ["errorStreamRedirect"],'rolloverPeriod',nil)
    obj[:syserr_rotation_size]              = get_xml_val( rexml_doc, ["errorStreamRedirect"],'rolloverSize',nil)
    obj[:syserr_rotation_backups]           = get_xml_val( rexml_doc, ["errorStreamRedirect"],'maxNumberOfBackupFiles',nil)


    obj
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def flush
    self.debug(__method__)
    unless @modifications == ""
      self.debug("Modifications present, flushing object to wsadmin")
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
#{sync_node}
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
AdminTask.setJVMProperties('[-nodeName #{resource[:nodename]} -serverName #{resource[:name]} -#{name} #{value}]')
     END
     cmd
   end

   # Helper method to change WebspherePluginSettings obj of the server
   def change_plugin_prop(prop, value)
     cmd = <<-END
obj = AdminConfig.list("WebserverPluginSettings", AdminConfig.getid("/Node:#{resource[:nodename]}/Server:#{resource[:name]}/"))
AdminConfig.modify(obj, '[[ #{prop} "#{value}" ]]')
     END
     cmd
   end

   # Helper method to change process execution properties
   def change_process_execution( prop, value)
     cmd = <<-END
obj = AdminConfig.list("ProcessExecution", AdminConfig.getid("/Node:#{resource[:nodename]}/Server:#{resource[:name]}/"))
AdminConfig.modify( obj, '[[#{prop} "#{value}"]]')
     END
     cmd
   end

   # Helper method to change threadpool values.
  def change_threadpool_value(threadpool, key, value)
    cmd = <<-END
the_id=AdminConfig.getid('/Node:#{resource[:nodename]}/Server:#{resource[:name]}/')
tpList=AdminConfig.list('ThreadPool', the_id).split("\\n")
for tp in tpList:
  if tp.count('#{threadpool}') == 1:
    tpdest=tp
AdminConfig.modify(tpdest, [['#{key}', "#{value}"]])
END
  cmd
end

  def change_stream_redirect( stream, key, value )
    cmd = <<-END
id=AdminConfig.getid('/Node:#{resource[:nodename]}/Server:#{resource[:name]}/')
sr=AdminConfig.showAttribute(id, "#{stream}")
AdminConfig.modify(sr, '[["#{key}" "#{value}"]]')
    END
    cmd
  end


  #  def plugin_props_connect_timeout=(value)
  #    @modifications += change_plugin_prop( 'ConnectTimeout', value)
  #  end
  #
  #  def plugin_props_server_io_timeout=(value)
  #    @modifications += change_plugin_prop('ServerIOTimeout', value)
  #  end
  #
  #  def umask=(value)
  #    @modifications += change_process_execution('umask', value)
  #  end
  #
  #  def runas_user=(value)
  #    @modifications += change_process_execution( 'runAsUser', value)
  #  end
  #
  #  def runas_group=(value)
  #    @modifications += change_process_execution( 'runAsGroup', value)
  #  end
  #
  # def jvm_initial_heap_size=(value)
  #   @modifications += jvm_property('initialHeapSize', resource[:jvm_initial_heap_size])
  # end
  #
  #  def jvm_maximum_heap_size=(value)
  #    @modifications += jvm_property('maximumHeapSize', resource[:jvm_maximum_heap_size])
  #  end
  #
  # def jvm_verbose_garbage_collection=(value)
  #   @modifications += jvm_property('verboseModeGarbageCollection', resource[:jvm_verbose_garbage_collection].to_s)
  # end
  #
  # def jvm_generic_jvm_arguments=(value)
  #   val = "\\\"" + resource[:jvm_generic_jvm_arguments].join(" ") + "\\\""
  #   @modifications += jvm_property('genericJvmArguments', val)
  # end


  #   def jvm_verbose_mode_class=(value)
  #     jvm_property('verboseModeClass', resource[:jvm_verbose_mode_class].to_s)
  #   end
  #
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

end
