# Provider for managing websphere cluster members.
# This parses the cluster member's "server.xml" to read current status, but
# uses the 'wsadmin' tool to make changes.  We cannot modify the xml data, as
# it's basically read-only.  wsadmin is painfully slow.
#
require 'puppet/provider/websphere_server'

Puppet::Type.type(:websphere_application_server).provide(:wsadmin, :parent => Puppet::Provider::Websphere_Server) do
  mk_resource_methods


  def self.prefetch(resources)
    # Prefetch does not seem to work with composite namevars. The resource's hash keys are the name param of the instance.
    # Getting the resources from the catalog object solves this problem
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
    servers = []
    Facter['was_profiles'].value.split(",").each do |profile_path|
      Dir.glob( profile_path + '/*/config/cells/**/server.xml').each do |f|
        clusterName = self.get_process_attribute('clusterName', f)
    #    isAs = self.get_process_attribute('xmlns:applicationserver', f)
          if clusterName.nil? #&& isAs != nil
          parts    = f.split("/")
          nodename = parts[-4]
          server   = parts[-2]
          profile  = parts[-9]
          obj = self.build_object("#{profile}:#{nodename}:#{server}", server,  f )
          servers.push(new(obj))
        end
       end
      end
      servers
  end

  def create()
    self.info("Create Method not implemented for clusterMembers")
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

 def jvm_verbose_garbage_collection=(value)
   @modifications += jvm_property('verboseModeGarbageCollection', resource[:jvm_verbose_garbage_collection].to_s)
 end

 def jvm_generic_jvm_arguments=(value)
   val = "\\\"" + resource[:jvm_generic_jvm_arguments].join(" ") + "\\\""
   @modifications += jvm_property('genericJvmArguments', val)
 end

 def threadpool_webcontainer_min_size=(value)
   @modifications += change_threadpool_value('WebContainer', 'minimumSize', value)
 end

 def threadpool_webcontainer_max_size=(value)
   @modifications += change_threadpool_value('WebContainer', 'maximumSize', value)
 end

 def sysout_rotation_type=(value)
   @modifications += change_stream_redirect('outputStreamRedirect', 'rolloverType', value)
 end

 def sysout_rotation_size=(value)
   @modifications += change_stream_redirect('outputStreamRedirect', 'rolloverSize', value)
 end

 def sysout_rotation_backups=(value)
   @modifications += change_stream_redirect('outputStreamRedirect', 'maxNumberOfBackupFiles', value)
 end

 def sysout_rotation_hour=(value)
   @modifications += change_stream_redirect('outputStreamRedirect', 'baseHour', value)
 end

 def sysout_rotation_period=(value)
   @modifications += change_stream_redirect('outputStreamRedirect', 'rolloverPeriod', value)
 end

 def syserr_rotation_type=(value)
   @modifications += change_stream_redirect('errorStreamRedirect', 'rolloverType', value)
 end

 def syserr_rotation_size=(value)
   @modifications += change_stream_redirect('errorStreamRedirect', 'rolloverSize', value)
 end

 def syserr_rotation_backups=(value)
   @modifications += change_stream_redirect('errorStreamRedirect', 'maxNumberOfBackupFiles', value)
 end

 def syserr_rotation_hour=(value)
   @modifications += change_stream_redirect('errorStreamRedirect', 'baseHour', value)
 end

 def syserr_rotation_period=(value)
   @modifications += change_stream_redirect('errorStreamRedirect', 'rolloverPeriod', value)
 end

end
