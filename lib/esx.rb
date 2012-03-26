require 'rubygems'
require 'rbvmomi'
require 'alchemist'
require 'net/scp'
require 'net/ssh'

module ESX

  VERSION = '0.4.1'
  
  if !defined? Log or Log.nil?
    Log = Logger.new($stdout)
    Log.formatter = proc do |severity, datetime, progname, msg|
        "[ESX] #{severity}: #{msg}\n"
    end
    Log.level = Logger::INFO unless (ENV["DEBUG"].eql? "yes" or \
                                     ENV["DEBUG"].eql? "true")
    Log.debug "Initializing logger"
  end

  class Host

    attr_reader :address, :user, :password
    attr_accessor :templates_dir

    def initialize(address, user, password, opts = {})
      @address = address
      @password = password
      @user = user
      @templates_dir = opts[:templates_dir] || "/vmfs/volumes/datastore1/esx-gem/templates"
    end

    # Connect to a ESX host
    #
    # Requires hostname/ip, username and password
    #
    # Host connection is insecure by default
    def self.connect(host, user, password, insecure=true)
      vim = RbVmomi::VIM.connect :host => host, :user => user, :password => password, :insecure => insecure
      host = Host.new(host, user,password)
      host.vim = vim
      host
    end

    def vim=(vim)
      @_vim = vim
      @_datacenter = @_vim.serviceInstance.find_datacenter
      @_host = @_datacenter.hostFolder.children.first.host.first
    end

    # Returns the name of this host
    #
    def name
      @_host.summary.config.name
    end

    # Host memory size in bytes
    #
    # returns a Fixnum
    #
    def memory_size
      @_host.hardware.memorySize.to_i
    end

    # Number of CPU cores available in this host
    #
    # returns a String
    #
    def cpu_cores
      @_host.hardware.cpuInfo.numCpuCores
    end

    # Power state of this host
    #
    # poweredOn, poweredOff
    #
    def power_state
      @_host.summary.runtime.powerState
    end
    
    # Host memory usage in bytes 
    # 
    # returns a Fixnum
    #
    def memory_usage
      @_host.summary.quickStats.overallMemoryUsage * 1024 * 1024
    end

    
    # Return a list of ESX::Datastore objects available in this host
    #
    def datastores
      datastores = []
      @_host.datastore.each do |ds|
        datastores << Datastore.wrap(ds)
      end
      datastores
    end

    # Create a Virtual Machine
    # 
    # Requires a Hash with the following keys:
    #
    # {
    #   :vm_name => name, (string, required)
    #   :cpus => 1, #(int, optional)
    #   :guest_id => 'otherGuest', #(string, optional)
    #   :disk_size => 4096,  #(in MB, optional)
    #   :memory => 128, #(in MB, optional)
    #   :datastore => datastore1 #(string, optional)
    #   :disk_file => path to vmdk inside datastore (optional)
    #   :disk_type => flat, sparse (default flat)
    # }
    #
    # supported guest_id list: 
    # http://pubs.vmware.com/vsphere-50/index.jsp?topic=/com.vmware.wssdk.apiref.doc_50/vim.vm.GuestOsDescriptor.GuestOsIdentifier.html
    #
    # Default values above.
    def create_vm(specification)
      spec = specification
      spec[:cpus] = (specification[:cpus] || 1).to_i
      spec[:guest_id] = specification[:guest_id] || 'otherGuest'
      if specification[:disk_size]
        spec[:disk_size] = (specification[:disk_size].to_i * 1024)
      else
        spec[:disk_size] = 4194304
      end
      spec[:memory] = (specification[:memory] || 128).to_i
      if specification[:datastore]
        spec[:datastore] = "[#{specification[:datastore]}]"
      else
        spec[:datastore] = '[datastore1]'
      end
      vm_cfg = {
        :name => spec[:vm_name],
        :guestId => spec[:guest_id],
        :files => { :vmPathName => spec[:datastore] },
        :numCPUs => spec[:cpus],
        :memoryMB => spec[:memory],
        :deviceChange => [
          {
            :operation => :add,
            :device => RbVmomi::VIM.VirtualLsiLogicController(
                             :key => 1000,
                             :busNumber => 0,
                             :sharedBus => :noSharing)
          }
        ],
        :extraConfig => [
          {
            :key => 'bios.bootOrder',
            :value => 'ethernet0'
          }
        ]
      }
      
      #Add multiple nics
      nics_count = 0
      if spec[:nics]
        spec[:nics].each do |nic_spec|
          vm_cfg[:deviceChange].push(
            {
              :operation => :add,
              :device => RbVmomi::VIM.VirtualE1000(create_net_dev(nics_count, nic_spec))
              
            }
          )
          nics_count += 1
        end
      end
      # VMDK provided, replace the empty vmdk
      vm_cfg[:deviceChange].push(create_disk_spec(:disk_file => spec[:disk_file], 
                                :disk_type => spec[:disk_type],
                                :disk_size => spec[:disk_size],
                                :datastore => spec[:datastore]))

      VM.wrap(@_datacenter.vmFolder.CreateVM_Task(:config => vm_cfg, :pool => @_datacenter.hostFolder.children.first.resourcePool).wait_for_completion)
    end

    def create_net_dev(nic_id, spec)
      h = {
        :key => nic_id,
        :deviceInfo => {
          :label => "Network Adapter #{nic_id}",
          :summary => spec[:network] || 'VM Network'
        },
        :backing => RbVmomi::VIM.VirtualEthernetCardNetworkBackingInfo(
          :deviceName => spec[:network] || 'VM Network'
        )
      }

      if spec[:mac_address]
        h[:macAddress] = spec[:mac_address]
        h[:addressType] = 'manual'
      else
        h[:addressType] = 'generated'
      end
      h
    end

    # Return product info as an array of strings containing
    # 
    # fullName, apiType, apiVersion, osType, productLineId, vendor, version
    # 
    def host_info 
      [
       @_host.summary.config.product.fullName,
       @_host.summary.config.product.apiType,
       @_host.summary.config.product.apiVersion,
       @_host.summary.config.product.osType,
       @_host.summary.config.product.productLineId,
       @_host.summary.config.product.vendor,
       @_host.summary.config.product.version
      ]
    end

    # Return a list of VM available in the inventory
    # 
    def virtual_machines
      vms = []
      vm = @_datacenter.vmFolder.childEntity.each do |x| 
        vms << VM.wrap(x)
      end
      vms
    end

    #
    # Run a command in the ESX host via SSH
    #
    def remote_command(cmd)
      output = ""
      Net::SSH.start(@address, @user, :password => @password) do |ssh|
        output = ssh.exec! cmd
      end
      output
    end

    #
    # Upload file
    #
    def upload_file(source, dest, print_progress = false)
      Net::SSH.start(@address, @user, :password => @password) do |ssh|
        Log.info "Uploading file #{File.basename(source)}..." if print_progress
        ssh.scp.upload!(source, dest) do |ch, name, sent, total|
          if print_progress
            print "\rProgress: #{(sent.to_f * 100 / total.to_f).to_i}% completed"
          end
        end
      end
    end

    def template_exist?(vmdk_file)
      template_file = File.join(@templates_dir, File.basename(vmdk_file))
      Log.debug "Checking if template #{template_file} exists"
      Net::SSH.start(@address, @user, :password => @password) do |ssh|
        return false if (ssh.exec! "ls -la #{@templates_dir} 2>/dev/null").nil?
        return false if (ssh.exec! "ls #{template_file} 2>/dev/null").nil?
      end
      Log.debug "Template #{template_file} found"
      true
    end
    alias :has_template? :template_exist?

    def list_templates
      templates = []
      Net::SSH.start(@address, @user, :password => @password) do |ssh|
        output = (ssh.exec! "ls -l #{@templates_dir}/*-flat.vmdk 2>/dev/null")
        output.each_line do |t|
          templates << t.gsub(/-flat\.vmdk/,".vmdk").split().last.strip.chomp rescue next
        end unless output.nil?
      end
      templates
    end

    #
    # Expects fooimg.vmdk
    # Trims path if /path/to/fooimg.vmdk
    #
    def delete_template(template_disk)
      Log.debug "deleting template #{template_disk}"
      template = File.join(@templates_dir, File.basename(template_disk))
      template_flat = File.join(@templates_dir, File.basename(template_disk, ".vmdk") + "-flat.vmdk")
      Net::SSH.start(@address, @user, :password => @password) do |ssh|
        if (ssh.exec! "ls #{template} 2>/dev/null").nil?
          Log.error "Template #{template_disk} does not exist"
          raise "Template does not exist" 
        end 
        ssh.exec!("rm -f #{template} && rm -f #{template_flat} 2>&1")
      end
    end

    def import_template(source, params = {})
      print_progress = params[:print_progress] || false
      dest_file = File.join(@templates_dir, File.basename(source))
      Log.debug "Importing template #{source} to #{dest_file}"
      return dest_file if template_exist?(dest_file)
      Net::SSH.start(@address, @user, :password => @password) do |ssh|
        if (ssh.exec! "ls -la #{@templates_dir} 2>/dev/null").nil?
          # Create template dir 
          Log.debug "Creating templates dir #{@templates_dir}"
          ssh.exec "mkdir -p #{@templates_dir}"
        end
      end
      import_disk_convert(source, dest_file, print_progress)
    end

    #
    # Expects vmdk source file path and destination path
    #
    # copy_from_template "/home/fooser/my.vmdk", "/vmfs/volumes/datastore1/foovm/foovm.vmdk"
    #
    # Destination directory must exist otherwise rises exception
    #
    def copy_from_template(template_disk, destination)
      Log.debug "Copying from template #{template_disk} to #{destination}"
      raise "Template does not exist" if not template_exist?(template_disk)
      source = File.join(@templates_dir, File.basename(template_disk))
      Net::SSH.start(@address, @user, :password => @password) do |ssh|
        Log.debug "Clone disk #{source} to #{destination}"
        Log.debug ssh.exec!("vmkfstools -i #{source} --diskformat thin #{destination} 2>&1")
      end
    end

    #
    # Imports a VMDK
    #
    # if params has :use_template => true, the disk is saved as a template in
    # @templates_dir and cloned from there.
    # 
    # Destination directory must exist otherwise rises exception
    #
    def import_disk(source, destination, print_progress = false, params = {})
      use_template = params[:use_template] || false
      if use_template
        Log.debug "import_disk :use_template => true"
        if !template_exist?(source)
          Log.debug "import_disk, template does not exist, importing."
          import_template(source, { :print_progress => print_progress })
        end
        copy_from_template(source, destination)
      else
        import_disk_convert source, destination, print_progress
      end
    end

    #
    # This method does all the heavy lifting when importing the disk.
    # It also converts the imported VMDK to thin format
    #
    def import_disk_convert(source, destination, print_progress = false)
      tmp_dest = destination + ".tmp"
      Net::SSH.start(@address, @user, :password => @password) do |ssh|
        if not (ssh.exec! "ls #{destination} 2>/dev/null").nil?
          raise Exception.new("Destination file #{destination} already exists")
        end
        Log.info "Uploading file... (#{File.basename(source)})" if print_progress
        ssh.scp.upload!(source, tmp_dest) do |ch, name, sent, total|
          if print_progress
            print "\rProgress: #{(sent.to_f * 100 / total.to_f).to_i}%"
          end
        end
        if print_progress
          Log.info "Converting disk..."
          ssh.exec "vmkfstools -i #{tmp_dest} --diskformat thin #{destination}; rm -f #{tmp_dest}"
        else
          ssh.exec "vmkfstools -i #{tmp_dest} --diskformat thin #{destination} >/dev/null 2>&1; rm -f #{tmp_dest}"
        end
      end
    end
    
    private
    #
    # disk_file
    # datastore
    # disk_size
    # disk_type
    #
    def create_disk_spec(params)
      disk_type = params[:disk_type] || :flat
      disk_file = params[:disk_file]
      if disk_type == :sparse and disk_file.nil?
        raise Exception.new("Creating sparse disks in ESX is not supported. Use an existing image.")
      end
      disk_size = params[:disk_size]
      datastore = params[:datastore]
      datastore = datastore + " #{disk_file}" if not disk_file.nil?
      spec = {}
      if disk_type == :sparse 
        spec = {
          :operation => :add,
          :device => RbVmomi::VIM.VirtualDisk(
                           :key => 0,
                           :backing => RbVmomi::VIM.VirtualDiskSparseVer2BackingInfo(
                                          :fileName => datastore,
                                          :diskMode => :persistent),
                           :controllerKey => 1000,
                           :unitNumber => 0,
                           :capacityInKB => disk_size)
        }
      else
        spec = {
          :operation => :add,
          :device => RbVmomi::VIM.VirtualDisk(
                           :key => 0,
                           :backing => RbVmomi::VIM.VirtualDiskFlatVer2BackingInfo(
                                          :fileName => datastore,
                                          :diskMode => :persistent),
                           :controllerKey => 1000,
                           :unitNumber => 0,
                           :capacityInKB => disk_size)
        }
      end
      spec[:fileOperation] = :create if disk_file.nil?
      spec
    end
  end

  class VM

    attr_accessor :memory_size, :cpus, :ethernet_cards_number
    attr_accessor :name, :virtual_disks_number, :vm_object

    # Wraps a RbVmomi::VirtualMachine object
    #
    # **This method should never be called manually.**
    #
    def self.wrap(vm)
      _vm = VM.new
      _vm.name = vm.name
      ## HACK: for some reason vm.summary.config.memorySizeMB returns nil
      # under some conditions
      _vm.memory_size = vm.summary.config.memorySizeMB*1024*1024 rescue 0
      _vm.cpus = vm.summary.config.numCpu
      _vm.ethernet_cards_number = vm.summary.config.numEthernetCards 
      _vm.virtual_disks_number = vm.summary.config.numVirtualDisks
      _vm.vm_object = vm
      _vm
    end

    # Returns the state of the VM as a string
    # 'poweredOff', 'poweredOn'
    # 
    def power_state
      vm_object.summary.runtime.powerState
    end

    # Power On a VM
    def power_on
      vm_object.PowerOnVM_Task.wait_for_completion
    end

    # Power Off a VM
    def power_off
      vm_object.PowerOffVM_Task.wait_for_completion
    end

    # Destroy the VirtualMaching removing it from the inventory
    # and deleting the disk files
    def destroy
      #disks = vm_object.config.hardware.device.grep(RbVmomi::VIM::VirtualDisk)
      vm_object.Destroy_Task.wait_for_completion
    end

    def reset
      vm_object.ResetVM_Task.wait_for_completion
    end

    def guest_info
      GuestInfo.wrap(vm_object.guest)
    end

    #
    # Shortcut to GuestInfo.ip_address
    #
    def ip_address
      guest_info.ip_address
    end

    def nics
      list = []
      vm_object.config.hardware.device.grep(RbVmomi::VIM::VirtualEthernetCard).each do |n|
        list << NetworkInterface.wrap(n)
      end
      list
    end

  end

  class NetworkInterface
    
    attr_accessor :_wrapped_object

    # Accepts VirtualEthernetCard and GuestNicInfo objects
    def self.wrap(obj)
      ni = NetworkInterface.new
      ni._wrapped_object = obj
      ni
    end

    # returns nil if the NetworkInterface is of type VirtualEthernetCard
    # returns the IP address if VMWare tools installed in guest and _wrapped_object is of
    # type GuestNicInfo
    def ip_address
      if _wrapped_object.is_a? RbVmomi::VIM::VirtualEthernetCard
        nil
      else
        _wrapped_object.ipAddress.first
      end
    end

    def mac
      _wrapped_object.macAddress 
    end

  end

  class GuestInfo

    attr_accessor :_wrapped_object

    def self.wrap(obj)
      gi = GuestInfo.new
      gi._wrapped_object = obj
      gi
    end

    def ip_address
      _wrapped_object.ipAddress
    end
    
    def nics
      n = []
      _wrapped_object.net.each do |nic|
        n << NetworkInterface.wrap(nic)
      end
      n
    end

    def tools_running_status
      _wrapped_object.toolsRunningStatus
    end

    def vmware_tools_installed?
      _wrapped_object.toolsRunningStatus != 'guestToolsNotRunning'
    end

  end

  class Datastore

    attr_accessor :name, :capacity, :datastore_type, :free_space, :accessible
    attr_accessor :url
    # Internal use only
    attr_accessor :_wrapped_object

    #
    # Internal method. Do not use
    #
    def self.wrap(ds)
      _ds = Datastore.new
      _ds._wrapped_object = ds
      _ds.name = ds.summary.name
      _ds.capacity = ds.summary.capacity
      _ds.free_space = ds.summary.freeSpace
      _ds.datastore_type = ds.summary.type
      _ds.accessible = ds.summary.accessible
      _ds.url = ds.summary.url
      _ds
    end

    def method_missing(name, *args)
      @_wrapped_object.send name, *args
    end

  end
end
