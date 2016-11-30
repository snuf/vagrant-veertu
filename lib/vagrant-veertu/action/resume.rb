module VagrantPlugins
  module ProviderVeertu
    module Action
      class Resume
        def initialize(app, env)
          @app = app
        end

        def call(env)
          current_state = env[:machine].state.id

          if current_state == :paused or current_state == :stopped
            env[:ui].info I18n.t("vagrant.actions.vm.resume.resuming")
            env[:machine].provider.driver.resume
          end
          @app.call(env)
        end
      end
    end
  end
end
