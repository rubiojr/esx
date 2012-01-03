require 'spec_helper'

describe "ESX Virtual Machine" do
  include ESXTestHelpers

  before do
    @test_host = ESX::Host.connect(esx_host, esx_user, esx_password)
  end
  
  after do
    @test_host.virtual_machines.each do |vm|
      vm.destroy
    end
  end

  it "should have an Array of NetworkInterfaces" do
    vm = create_simple_vm
    vm.nics.size.should eql(1)
    vm.nics.first.should be_a ESX::NetworkInterface
  end 
 
  it "should have valid property types" do
    vm = create_simple_vm
    vm.memory_size.should be_a Fixnum 
    vm.memory_size.should be > 0
    vm.nics.should be_an Array
    vm.power_state.should be_a String
  end
  
end

