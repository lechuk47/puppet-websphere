# Provider for managing WebSphere clusters via 'wsadmin'
# wsadmin is a slow piece of something. It exits 0 for everything and appears
# to spin up a JVM for every interaction with it, so it's terribly slow. You
# can talk to it in 'jacl' or 'jython'
#
# This thing needs some love - some Ruby refinement.
# Basically, the user-provided attribute values determine what command to use
# via the profile_base.  The 'wsadmin' command to use depends on what profile
# we're working with, and a system can have several profiles.
#
# This provider should just handle the creating and removal of clusters.
require 'puppet/provider/websphere_helper'

Puppet::Type.type(:websphere_cluster).provide(:websphere_server, :parent => Puppet::Provider::Websphere_Server) do
# Puppet::Type.type(:websphere_cluster).provide(
#   :wsadmin,
#   :parent => Puppet::Provider::Websphere_Helper
# ) do

  def self.instances
    []
  end

  def exists?
    # This will output an empty string: '' if there are no clusters.
    # If a cluster is present, it will output:
    #   test_cluster(cells/dmgrCell01/clusters/test_cluster|cluster.xml#ServerCluster_1421550161639)'
    # Unfortunately, it does *not* give a good exit code. It always exits 0

    cmd = "\"AdminConfig.getid('/ServerCluster:"
    cmd += resource[:name]
    cmd += "/')\""

    result = wsadmin(:command => cmd, :user => resource[:user])

    return false unless result.include?(resource[:name])
    true
  end

  def create
    # Need some error handling here, I suppose. Unfortunately, wsadmin always
    # exits 0
    cmd = "\"AdminTask.createCluster('[-clusterConfig [-clusterName "
    cmd += resource[:name]
    cmd += "]]')\""

    self.debug "wsadmin: Creating cluster via #{cmd}"

    result = wsadmin(:command => cmd, :user => resource[:user])
    self.debug result
  end

  def destroy
    # Need some error handling here, I suppose. Unfortunately, wsadmin always
    # exits 0
    # We also might need to handle stopping the cluster first.
    cmd = "\"AdminTask.deleteCluster('[-clusterName "
    cmd += resource[:name]
    cmd += "]')\""

    self.debug "Deleting cluster via #{wascmd}#{cmd}"

    result = wsadmin(:command => cmd, :user => resource[:user])

    self.debug result
  end

  def flush

  end

end
