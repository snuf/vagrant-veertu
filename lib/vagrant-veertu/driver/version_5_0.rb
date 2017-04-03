require 'log4r'
require 'json'
require "vagrant/util/platform"

require File.expand_path("../base", __FILE__)

module VagrantPlugins
  module ProviderVeertu
    module Driver
      # Driver for Veertu 1.2.0.x
      class Version_5_0 < Base
        def initialize(uuid)
          super()

          @logger = Log4r::Logger.new("vagrant::provider::veertu_5_0")
          @uuid = uuid
        end
        
        def read_bridged_interfaces
          raise Errors::VeertuUnsupported, action: 'bridged interfaces'
        end

        def clear_forwarded_ports
          read_forwarded_ports(@uuid).each do |nic, name, _, _|
            execute("modify", @uuid, 'delete', 'port_forwarding', name)
          end
        end

        def delete
          execute("delete",'--yes', @uuid)
        end

        def execute_command(command)
          execute(*command)
        end

        def export(path)
          execute("export", @uuid, path.to_s, '--fmt=box')
        end

        def forward_ports(ports)
          ports.each do |options|
            name = options[:name]
            protocol = options[:protocol] || "tcp"
            host_ip = options[:hostip] || "127.0.0.1"
            host_port = options[:hostport]
            guest_ip = options[:guestip] || ""
            guest_port = options[:guestport]
            execute('--machine-readable', 'modify', @uuid, 'add', 'port_forwarding', name, '--host-ip',
                    host_ip, '--host-port', host_port.to_s, '--protocol', protocol, '--guest-ip',
                    guest_ip, '--guest-port', guest_port.to_s)

          end
        end

        def get_machine_id(machine_name)
          vm = get_vm_info(machine_name)
          return vm['id'] 
        end
        
        def set_name(name)
          execute('modify', @uuid, 'set', '--name', name)  
        end
        
        def halt
          execute("shutdown", @uuid)
        end

        def import(box)
          box = Vagrant::Util::Platform.cygwin_windows_path(box)

          output = ""
          total = ""
          last  = 0

          # Dry-run the import to get the suggested name and path
          @logger.debug("Doing dry-run import to determine parallel-safe name...")
          output = execute("import", "-n", box)
          result = /Suggested VM name "(.+?)"/.match(output)
          puts result
          if !result
            raise Errors::VeertuManageNoNameError, output: output
          end
          suggested_name = result[1].to_s

          # Append millisecond plus a random to the path in case we're
          # importing the same box elsewhere.
          specified_name = "#{suggested_name}_#{(Time.now.to_f * 1000.0).to_i}_#{rand(100000)}"
          @logger.debug("-- Parallel safe name: #{specified_name}")

          # Build the specified name param list
          name_params = [
            "--os-family", "0",
            "--name", specified_name,
          ]

          # Extract the disks list and build the disk target params
          disk_params = []
          disks = output.scan(/(\d+): Hard disk image: source image=.+, target path=(.+),/)
          disks.each do |unit_num, path|
            disk_params << "--vsys"
            disk_params << "0"
            disk_params << "--unit"
            disk_params << unit_num
            disk_params << "--disk"
            disk_params << path.reverse.sub("/#{suggested_name}/".reverse, "/#{specified_name}/".reverse).reverse # Replace only last occurrence
          end
          success_json = execute("--machine-readable", "import", box , *name_params, *disk_params)
          begin
            success = JSON.parse(success_json)
            if success['status'] == 'ok'
              puts 'imported successfully'
            end
          rescue JSON::ParserError
            puts 'json parse error'
            return nil
          end
          puts specified_name
          machine_id = get_machine_id(specified_name)
          puts machine_id
          return machine_id 
        end

        def read_forwarded_ports(uuid=nil, active_only=false)
          uuid ||= @uuid

          @logger.debug("read_forward_ports: uuid=#{uuid} active_only=#{active_only}")

          results = []
          current_nic = 'nat'
          vm_info = get_vm_info(uuid)
          if active_only && vm_info['status'] != "running"
                return []
          end
          port_forwarding_rules = vm_info['port_forwarding']
          
          port_forwarding_rules.each do |rule|
            result = [current_nic, rule['name'], rule['host_port'], rule['guest_port']]
            results << result
            @logger.debug("  - #{result.inspect}")
          end

          results
        end

        def read_host_only_interfaces
          vms_array = get_vm_list()
          info = {}
          vms_array.each do |vm|
            info['name'] = vm['name']
            info['uuid'] = vm['id']
          end
          info
        end

        def read_network_interfaces
          return { '0' => {:type => :nat}, '1' => {:type => :bridged}}
        end

        def read_state
          vm = get_vm_info(@uuid)
          status =  vm['status']
          @logger.debug('getting machine status')
          @logger.debug(status)
          return status.to_sym
        end

        def read_used_ports
          ports = []
          vms_array = get_vm_list()
          vms_array.each do |vm|
              # Ignore our own used ports
              uuid = vm['uuid']
              next if uuid  == @uuid

              read_forwarded_ports(uuid, true).each do |_, _, hostport, _|
                ports << hostport
              end
          end

          ports
        end

        def read_guest_ip(adapter_number)
          vm_info = get_vm_info(@uuid)
          return vm_info['ip']
        end

        def read_vms
          results = {}
          vms = get_vm_list()
          vms.each do |vm|
            results[vm[:id]] = vm[:name]
          end
          results
        end


        def ssh_port(expected_port)
          expected_port = expected_port.to_s
          @logger.debug("Searching for SSH port: #{expected_port.inspect}")

          # Look for the forwarded port only by comparing the guest port
          read_forwarded_ports.each do |_, _, hostport, guestport|
            if guestport == expected_port
              return hostport
            end
          end

          nil
        end

        def resume
          start(nil)
        end

        def start(mode)
          if mode == 'headless'
            execute('--machine-readable', 'modify', @uuid, 'set', '--headless', '1')
          elsif mode == 'gui'
            execute('--machine-readable', 'modify', @uuid, 'set', '--headless', '0')
          end
          json_success  = execute('--machine-readable', 'start', @uuid)
          result = JSON.parse(json_success)
          if result['status'] == 'OK'
            return true
          end

          # If we reached this point then it didn't work out.
          raise Vagrant::Errors::VeertuManageError,
            command: command.inspect,
            stderr: r.stderr
        end

        def suspend
          execute("pause", @uuid)
        end

        def verify!
          # This command sometimes fails if kernel drivers aren't properly loaded
          # so we just run the command and verify that it succeeded.
          execute("list", retryable: true)
        end

        def vm_exists?(uuid)
          5.times do |i|
            info = get_vm_info(uuid)
            if info
              return true
            else
              return false
            end
            sleep 2
          end

          # If we reach this point, it means that we consistently got the
          # failure, do a standard veertumanage now. This will raise an
          # exception if it fails again.
          execute("show", uuid)
          return true
        end

        def read_mac_address
          vm_describe = get_vm_describe(@uuid)
          network_cards = vm_describe['hardware']["network cards"]
          if not network_cards
            return nil
          end
          if network_cards.is_a?(Hash)
            network_card = network_cards
          else
            network_card = network_cards.pop(0)
          end
          puts network_card
          return network_card['mac address']
        end
        
        def enable_adapters(adapters)
          vm_describe = get_vm_describe(@uuid)
          puts vm_describe
          if vm_describe.empty?
            network_cards = []
          else
            network_cards = vm_describe['hardware']["network cards"]
            if network_cards.is_a?(Hash)
              network_cards = [network_cards]
            end
          end
          if network_cards.nil?
            network_cards = []
          end
          
          puts adapters
          network_cards.each do |net_card| # set our net cards to be desired type by config 
            adapter = adapters.pop()
            set_card(net_card['card index'], adapter[:type])
          end
          adapters.each do |adapter| # in case there are more adapters - add them
            add_card(adapter[:type])
          end
        end
        protected
        
        def has_adapter?(network_cards, type)
          type_str = type_symbol_to_veertu_str(type)
          network_cards.each do |network_card|
            if network_card['connection'] == type_str
              return network_card['card index']
            end
          end
          return nil
        end
        
        def add_card(type)
          type_str = type_symbol_to_veertu_str(type)
          response = execute('modify', @uuid, 'add', 'network_card', '--type', type_str)
          @logger.info(response)
        end
        
        def set_card(index, type)
          type_str = type_symbol_to_veertu_str(type)
          response = execute('modify', @uuid, 'set', '--network', index, '--network-type', type_str)
          @logger.info(response)
        end
         
        def type_symbol_to_veertu_str(type) 
          if type == :nat
            return 'host'
          elsif type == :bridged
            return 'shared'
          end
          return 'disconnected'
        end
        
        def get_vm_list()
          vms_json = execute("--machine-readable", "list", retryable: true)
          vms = JSON.parse(vms_json)
          return vms['body']
        end
        
        def get_vm_info(uuid)
          # puts caller
          begin
            vm_info_json = execute('--machine-readable', 'show', uuid, retryable: true)
            vm_info = JSON.parse(vm_info_json)
            body = vm_info['body']
            return body
          rescue JSON::ParserError
            return nil
          end
        end
        
        def get_vm_describe(uuid)
          begin
            vm_info_json = execute('--machine-readable', 'describe', uuid, retryable: true)
            vm_info = JSON.parse(vm_info_json)
            body = vm_info['body']
            return body
          rescue JSON::ParserError
            return nil
          end
        end
      end
    end
  end
end
