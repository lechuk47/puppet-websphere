# Provider for managing websphere cluster members.
# This parses the cluster member's "server.xml" to read current status, but
# uses the 'wsadmin' tool to make changes.  We cannot modify the xml data, as
# it's basically read-only.  wsadmin is painfully slow.
#
require 'puppet/provider/websphere_server'

Puppet::Type.type(:websphere_cluster_member).provide(:wsadmin, :parent => Puppet::Provider::Websphere_Server) do

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
    self.debug("instances")
    servers = []
    Facter['was_profiles'].value.split(",").each do |profile_path|
      Dir.glob( profile_path + '/*/config/cells/**/server.xml').each do |f|
        self.debug("Getting info from " + f)
        clusterName = self.get_process_attribute('clusterName', f).to_s
        if  clusterName != ""
          parts    = f.split("/")
          nodename = parts[-4]
          server   = parts[-2]
          profile  = parts[-9]
          obj = self.build_object("#{profile}:#{nodename}:#{clusterName}:#{server}", server,  f )
          servers.push(new(obj))
        end
       end
      end
      servers
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


end
