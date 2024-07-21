module Hiccdown
  class Railtie < Rails::Railtie
    initializer 'hiccdown.action_controller' do
      ActiveSupport.on_load(:action_controller) do
        include CustomViewRendering
      end
    end
  end

  module CustomViewRendering
    extend ActiveSupport::Concern

    included do
      alias_method :original_render, :render
      alias_method :original_default_render, :default_render
      alias_method :default_render, :custom_default_render
    end

    def custom_default_render(*args)
      action_name = params[:action]
      helper_module = "#{self.class.name.gsub('Controller', '')}Helper".constantize

      if helper_module.instance_methods(false).include?(action_name.to_sym)
        content = helper_module.instance_method(action_name).bind(view_context).call
        original_render html: Hiccdown::to_html(content).html_safe
      else
        original_default_render(*args)
      end
    rescue => e
      Rails.logger.error "Hiccdown CustomViewRendering error: #{e.message}"
      original_default_render(*args)
    end
  end
end
