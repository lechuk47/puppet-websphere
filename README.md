# Puppet module for managing websphere servers and objects
## based on joshbeard websphere module

This module is not intended for the complete management of websphere application server at the moment. I use this module to check and apply configurations to j2ee resources and servers ( servers including cluster members, standalone application servers, ODR,etc.)

This module reads all the configuration from the local profiles of the node and apply the changes using the wsadmin tool of the profile pf the resource. All the custom providers implements self.instances and self.prefetch ( puppet resource is working ). Also all the changes are flushed at once with the flush method.
