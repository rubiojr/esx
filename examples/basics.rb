require 'rubygems'
require 'lib/esx.rb'


# Connect to the ESX Host
host = ESX::Host.connect 'my-esx-host', 'root', 'secret'

# Print hypervisor info
puts
name = host.name.upcase
puts "*" * name.size
puts name
puts "*" * name.size
puts "Memory Size:      %s" % host.memory_size.bytes.to.megabytes.to_i
puts "Memory Usage:     %s" % host.memory_usage.bytes.to.megabytes.to_i
puts "Cpu Cores:        %s" % host.cpu_cores
puts "Power State:      %s" % host.power_state

# Create a VM with 4GB disk, 128 MB mem, e1000 nic, 1CPU in datastore1
vm = host.create_vm :vm_name => 'foobar'

# Create a VM with 5GB disk, 256 MB mem, e1000 nic, 1CPU in datastore2
vm = host.create_vm :vm_name => 'foobar2', :disk_size => 5000, :cpus => 2, :memory => 256, :datastore => 'datastore2'


host.virtual_machines.each do |vm|

  # PowerOff the VM if powered On
  vm.power_off if (vm.name =~ /foobar/ and vm.power_state == 'poweredOn')

  # Destroy the VM if name matches foobar
  if vm.name =~ /foobar.*/
    vm.destroy
  end

end
