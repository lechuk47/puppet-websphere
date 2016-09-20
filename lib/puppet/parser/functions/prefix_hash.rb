module Puppet::Parser::Functions
      newfunction(:prefix_hash, :type=> :rvalue) do |args|
        hash = args[0]
        prefix = args[1]
        newhash = Hash.new
        k = ""
        hash.each do |key,value|
           newhash[prefix + key] = hash[key]
         end
        return newhash
      end
end
