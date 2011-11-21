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
    "esx-test-host"
  end

  def esx_user
    "root"
  end

  def esx_password
    ""
  end

end
