# ESX

Simple rbvmomi wrapper to manage VMWare ESX hosts. 

The goal of the library is to keep things simple so vCenter support isn't planned.

If you want a full VMWare vSphere API ruby implementation have a look at https://github.com/rlane/rbvmomi

# Installation

  gem install esx

# Usage


Usage: esx --help

## Available Commands

_esx info --user root --password foo 10.10.0.2_

Sample output:

    *********
    ESXHOST1
    *********
    Memory Size:      32756
    Memory Usage:     7429
    Cpu Cores:        8
    Power State:      poweredOn
    
    Virtual Machines:
    +-------------------------+--------+------+------+-------+
    | NAME                    | MEMORY | CPUS | NICS | DISKS |
    +-------------------------+--------+------+------+-------+
    | foobar                  | 128    | 1    | 1    | 1     |
    | foobar2                 | 256    | 2    | 1    | 1     |
    +-------------------------+--------+------+------+-------+
    
    Datastores:
    +------------+--------------+--------------+-----------+------+---------------------------------------------------+
    | NAME       | CAPACITY     | FREESPACE    | ACCESIBLE | TYPE | URL                                               |
    +------------+--------------+--------------+-----------+------+---------------------------------------------------+
    | datastore2 | 146565758976 | 145547591680 | VMFS      | true | /vmfs/volumes/4e611c69-16474ca5-d290-5ef3fc9a99c3 |
    | datastore1 | 141465485312 | 20716716032  | VMFS      | true | /vmfs/volumes/4e6117e7-35c82a3e-ba79-5cf3fc9699c2 |
    +------------+--------------+--------------+-----------+------+---------------------------------------------------+

_esx create-vm --user root --password foo --name esx-rubiojr --disk-file /path/to/file.vmdk --datastore datastore1 --memory 2048 --poweron 10.10.0.2_




# Using the library

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

# Copyright

Copyright (c) 2011 Sergio Rubio. See LICENSE.txt for
further details.

