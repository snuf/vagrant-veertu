require "fileutils"

module VagrantPlugins
  module ProviderVeertu
    module Action
      class Export
        def initialize(app, env)
          @app = app
          @logger = Log4r::Logger.new("vagrant::provider::veertu_5_0")
        end

        def call(env)
          @env = env

	  #env[:ui].output(@env[:machine].state.id)
          raise Vagrant::Errors::VMPowerOffToPackage if \
            @env[:machine].state.id != :stopped

          export

          @app.call(env)
        end

        def export
          @env[:ui].info I18n.t("vagrant.actions.vm.export.exporting")
          @env[:machine].provider.driver.export(ovf_path) do |progress|
            @env[:ui].clear_line
            @env[:ui].report_progress(progress, 100, false)
          end

          # Clear the line a final time so the next data can appear
          # alone on the line.
          @env[:ui].clear_line
        end

        def ovf_path
          File.join(@env["export.temp_dir"], "box.vmz")
        end
      end
    end
  end
end
