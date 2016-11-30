module VagrantPlugins
  module ProviderVeertu
    module Errors
      class VeertuError < Vagrant::Errors::VagrantError
        error_namespace('vagrant_veertu.errors')
      end
      class VeertuUnsupported < VeertuError
        error_key(:veertumanage_unsupported)
      end
      class VeertuManageError < VeertuError
        error_key(:veertumanage_error)
      end
      class VeertuManageNotFoundError < VeertuManageError
        error_key(:veertumanage_notfound_error)
      end
      class VeertuManageNoNameError < VeertuError
        error_key(:veertumanage_no_name_error)
      end
    end
  end
end
