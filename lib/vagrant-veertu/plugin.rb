require "vagrant"

module VagrantPlugins
  module ProviderVeertu
    class Plugin < Vagrant.plugin("2")
      name "Veertu provider"
      description <<-EOF
      The Veertu provider allows Vagrant to manage and control
      Veertu-based virtual machines.
      EOF

      provider(:veertu, priority: 6) do
        require File.expand_path("../provider", __FILE__)
        Provider
      end

      config(:veertu, :provider) do
        require File.expand_path("../config", __FILE__)
        Config
      end

      config(:veertu, :provider) do
        require File.expand_path("../config", __FILE__)
        setup_i18n
        Config
      end

      synced_folder(:veertu) do
        require File.expand_path("../synced_folder", __FILE__)
        SyncedFolder
      end

      provider_capability(:veertu, :forwarded_ports) do
        require_relative "cap"
        Cap
      end

      provider_capability(:veertu, :nic_mac_addresses) do
        require_relative "cap"
        Cap
      end

      provider_capability(:veertu, :public_address) do
        require_relative "cap/public_address"
        Cap::PublicAddress
      end

      provider_capability(:veertu, :snapshot_list) do
        require_relative "cap"
        Cap
      end

      def self.setup_i18n
        I18n.load_path << File.expand_path("locales/en.yml", ProviderVeertu.source_root)
        I18n.reload!
      end
    end

    autoload :Action, File.expand_path("../action", __FILE__)

    # Drop some autoloads in here to optimize the performance of loading
    # our drivers only when they are needed.
    module Driver
      autoload :Meta, File.expand_path("../driver/meta", __FILE__)
      autoload :Version_5_0, File.expand_path("../driver/version_5_0", __FILE__)
    end

    module Model
      autoload :ForwardedPort, File.expand_path("../model/forwarded_port", __FILE__)
    end

    module Util
      autoload :CompileForwardedPorts, File.expand_path("../util/compile_forwarded_ports", __FILE__)
    end
  end
end
