require 'rubygems'
require 'rspec/autorun'
require 'simplecov'

SimpleCov.start do 
  add_filter '/spec/'
end

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'esx'

module ESXTestHelpers
  
  def esx_host
    ENV["ESX_HOST"] || "esx-test-host"
  end

  def esx_user
    ENV["ESX_USER"] || "root"
  end

  def esx_password
    ENV["ESX_PASSWORD"] || ""
  end

  def test_data_dir
    File.dirname(__FILE__) + '/data'
  end

  def test_host_object
    @test_host = ESX::Host.connect(esx_host, esx_user, esx_password)
  end
  
  def create_simple_vm
    name = 'test1GB'
    disk_size = 1024
    datastore = 'datastore1'
    guest_id = 'otherGuest'
    memory = 512
    nics = [{ :mac_address => nil, :network => nil }]

    vm = test_host_object.create_vm :vm_name => name, 
                        :datastore => datastore, :disk_type => :flat, :memory => memory,
                        :disk_size => disk_size,
                        :guest_id => guest_id, :nics => nics
    vm
  end

end
