require 'rails/engine'

module ClowderCommonRuby
  class Engine < ::Rails::Engine
    isolate_namespace(ClowderCommonRuby)
  end
end
