require "forwardable"
require "thread"

require "log4r"

require "vagrant/util/retryable"

require File.expand_path("../base", __FILE__)

module VagrantPlugins
  module ProviderVeertu
    module Driver
      class Meta < Base
        # This is raised if the VM is not found when initializing a driver
        # with a UUID.
        class VMNotFound < StandardError; end

        # We use forwardable to do all our driver forwarding
        extend Forwardable

        # We cache the read Veertu version here once we have one,
        # since during the execution of Vagrant, it likely doesn't change.
        @@version = nil
        @@version_lock = Mutex.new

        # The UUID of the virtual machine we represent
        attr_reader :uuid

        # The version of veertu that is running.
        attr_reader :version

        include Vagrant::Util::Retryable

        def initialize(uuid=nil)
          # Setup the base
          super()

          @logger = Log4r::Logger.new("vagrant::provider::veertu::meta")
          @uuid = uuid

          @@version_lock.synchronize do
            if !@@version
              # Read and assign the version of Veertu we know which
              # specific driver to instantiate.
              begin
                @@version = read_version
              rescue Vagrant::Errors::CommandUnavailable,
                Vagrant::Errors::CommandUnavailableWindows
                # This means that Veertu was not found, so we raise this
                # error here.
                raise Vagrant::Errors::VeertuNotDetected
              end
            end
          end

          # Instantiate the proper version driver for Veertu
          @logger.debug("Finding driver for Veertu version: #{@@version}")
          driver_map   = {
            "5.0" => Version_5_0,
          }

          driver_klass = nil
          driver_map.each do |key, klass|
            if @@version.start_with?(key)
              driver_klass = klass
              break
            end
          end

          if !driver_klass
            supported_versions = driver_map.keys.sort.join(", ")
            raise Vagrant::Errors::VeertuInvalidVersion,
              supported_versions: supported_versions
          end

          @logger.info("Using Veertu driver: #{driver_klass}")
          @driver = driver_klass.new(@uuid)
          @version = @@version

          if @uuid
            # Verify the VM exists, and if it doesn't, then don't worry
            # about it (mark the UUID as nil)
            raise VMNotFound if !@driver.vm_exists?(@uuid)
          end
        end

        def_delegators :@driver, :clear_forwarded_ports,
          :clear_shared_folders,
          :clonevm,
          :create_dhcp_server,
          :create_host_only_network,
          :create_snapshot,
          :delete,
          :delete_snapshot,
          :delete_unused_host_only_networks,
          :discard_saved_state,
          :enable_adapters,
          :execute_command,
          :export,
          :forward_ports,
          :halt,
          :import,
          :list_snapshots,
          :read_forwarded_ports,
          :read_bridged_interfaces,
          :read_dhcp_servers,
          :read_guest_additions_version,
          :read_guest_ip,
          :read_guest_property,
          :read_host_only_interfaces,
          :read_mac_address,
          :read_mac_addresses,
          :read_machine_folder,
          :read_network_interfaces,
          :read_state,
          :read_used_ports,
          :read_vms,
          :reconfig_host_only,
          :remove_dhcp_server,
          :restore_snapshot,
          :resume,
          :set_mac_address,
          :set_name,
          :share_folders,
          :ssh_port,
          :start,
          :suspend,
          :verify!,
          :verify_image,
          :vm_exists?

        protected

        # This returns the version of Veertu that is running.
        #
        # @return [String]
        def read_version
          '5.0'
        end
      end
    end
  end
end
