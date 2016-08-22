#Facter to collect all the websphere profiles in the current node




profilepaths = [
  "/opt/IBM/BPM*/profiles",
  "/opt/IBM/WAS*/profiles",
  "/wascfg*/profiles",
]

 Facter.add('was_profiles') do
   setcode do
    profilepaths.collect{ |path| Dir.glob(path).join(",")}.reject{ |x| x == "" }.join(",")
  end
end
