require 'log4r'
require 'inifile'

require 'vagrant/util/busy'
require 'vagrant/util/platform'
require 'vagrant/util/retryable'
require 'vagrant/util/subprocess'
require 'vagrant/util/which'

module VagrantPlugins
  module ProviderVeertu
    module Driver
      # Base class for all VeertuManage drivers.
      #
      # This class provides useful tools for things such as executing
      # VeertuManage and handling SIGINTs and so on.
      class Base
        # Include this so we can use `Subprocess` more easily.
        include Vagrant::Util::Retryable

        def initialize
          @logger = Log4r::Logger.new("vagrant::provider::veertu::base")

          # This flag is used to keep track of interrupted state (SIGINT)
          @interrupted = false
          default_paths = ["/Applications/Veertu.app/Contents/SharedSupport/VeertuManage", 
                           "/Applications/Veertu Desktop.app/Contents/SharedSupport/VeertuManage"]
          ini_file = File.expand_path("~/.veertu_config")
          if File.exist?(ini_file) then
              file = IniFile.load(ini_file)
              @veertumanage_path = file['VAGRANT']['manage_path']
          else
              default_paths.each do |veertu_path|
                if File.exist?(veertu_path)
                  @veertumanage_path = veertu_path
                  break
                end
              end
          end
          @logger.info("VeertuManage path: #{@veertumanage_path}")
          if !@veertumanage_path
            raise Errors::VeertuManageNotFoundError
          end

          
        end

        # Clears the forwarded ports that have been set on the virtual machine.
        def clear_forwarded_ports
        end
      
        def max_network_adapters
          36
        end

        # Deletes the virtual machine references by this driver.
        def delete
        end

        # Execute a raw command straight through to VeertuManage.
        #
        # Accepts a retryable: true option if the command should be retried
        # upon failure.
        #
        # Raises a VeertuManage error if it fails.
        #
        # @param [Array] command Command to execute.
        def execute_command(command)
        end

        # Exports the virtual machine to the given path.
        #
        # @param [String] path Path to the OVF file.
        # @yield [progress] Yields the block with the progress of the export.
        def export(path)
          raise NotImplementedError("please export manually")
        end

        # Forwards a set of ports for a VM.
        #
        # This will not affect any previously set forwarded ports,
        # so be sure to delete those if you need to.
        #
        # The format of each port hash should be the following:
        #
        #     {
        #       name: "foo",
        #       hostport: 8500,
        #       guestport: 80,
        #       adapter: 1,
        #       protocol: "tcp"
        #     }
        #
        # Note that "adapter" and "protocol" are optional and will default
        # to 1 and "tcp" respectively.
        #
        # @param [Array<Hash>] ports An array of ports to set. See documentation
        #   for more information on the format.
        def forward_ports(ports)
        end

        # Halts the virtual machine (pulls the plug).
        def halt
        end

        # Imports the VM from an box file.
        #
        # @param [String] box Path to the box file.
        # @return [String] UUID of the imported VM.
        def import(box)
        end


        # Returns a list of forwarded ports for a VM.
        #
        # @param [String] uuid UUID of the VM to read from, or `nil` if this
        #   VM.
        # @param [Boolean] active_only If true, only VMs that are running will
        #   be checked.
        # @return [Array<Array>]
        def read_forwarded_ports(uuid=nil, active_only=false)
        end

        # Returns the current state of this VM.
        #
        # @return [Symbol]
        def read_state
        end

        # Returns a list of all forwarded ports in use by active
        # virtual machines.
        #
        # @return [Array]
        def read_used_ports
        end

        # Returns a list of all UUIDs of virtual machines currently
        # known by Veertu.
        #
        # @return [Array<String>]
        def read_vms
        end

        # Share a set of folders on this VM.
        #
        # @param [Array<Hash>] folders
        def share_folders(folders)
        end

        # Reads the SSH port of this VM.
        #
        # @param [Integer] expected Expected guest port of SSH.
        def ssh_port(expected)
        end

        # Starts the virtual machine.
        #
        # @param [String] mode Mode to boot the VM. Either "headless"
        #   or "gui"
        def start(mode)
        end

        # Suspend the virtual machine.
        def suspend
        end


        # Verifies that the driver is ready to accept work.
        #
        # This should raise a VagrantError if things are not ready.
        def verify!
        end


        # Checks if a VM with the given UUID exists.
        #
        # @return [Boolean]
        def vm_exists?(uuid)
        end

        # Execute the given subcommand for VeertuManage and return the output.
        def execute(*command, &block)
          # Get the options hash if it exists
          opts = {}
          opts = command.pop if command.last.is_a?(Hash)

          tries = 0
          tries = 3 if opts[:retryable]

          # Variable to store our execution result
          r = nil

          retryable(on: VagrantPlugins::ProviderVeertu::Errors::VeertuManageError, tries: tries, sleep: 1) do
            # If there is an error with VeertuManage, this gets set to true
            errored = false

            # Execute the command
            r = raw(*command, &block)

            # If the command was a failure, then raise an exception that is
            # nicely handled by Vagrant.
            if r.exit_code != 0
              if @interrupted
                @logger.info("Exit code != 0, but interrupted. Ignoring.")
              elsif r.exit_code == 126
                # This exit code happens if VeertuManage is on the PATH,
                # but another executable it tries to execute is missing.
                raise Errors::VeertuManageNotFoundError
              else
                errored = true
              end
            end

            # If there was an error running VeertuManage, show the error and the
            # output.
            if errored
              raise VagrantPlugins::ProviderVeertu::Errors::VeertuManageError,
                command: command.inspect,
                stderr:  r.stderr,
                stdout:  r.stdout
            end
          end

          r.stdout.gsub("\r\n", "\n")
        end

        # Executes a command and returns the raw result object.
        def raw(*command, &block)
          int_callback = lambda do
            @interrupted = true

            # We have to execute this in a thread due to trap contexts
            # and locks.
            Thread.new { @logger.info("Interrupted.") }.join
          end

          # Append in the options for subprocess
          command << { notify: [:stdout, :stderr] }

          Vagrant::Util::Busy.busy(int_callback) do
            @logger.debug(YAML::dump(command))
            Vagrant::Util::Subprocess.execute(@veertumanage_path, *command, &block)
          end
        rescue Vagrant::Util::Subprocess::LaunchError => e
          raise Vagrant::Errors::VeertuManageLaunchError,
            message: e.to_s
        end
      end
    end
  end
end
