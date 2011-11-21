require 'spec_helper'

describe "ESX host" do
  include ESXTestHelpers

  before do
    @test_host = ESX::Host.connect(esx_host, esx_user, esx_password)
  end

  it "connects to and ESX with a valid user/pass" do
    host = nil
    lambda do
      host = ESX::Host.connect(esx_host, esx_user, esx_password)
    end.should_not raise_error
    
  end

  it "retrives the host name" do
    @test_host.name.should_not be_nil
  end
end
