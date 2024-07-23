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
      alias_method :render, :custom_render
      alias_method :default_render, :custom_default_render
    end

    def custom_render *args
      options = args.extract_options!

      # Implicit rendering
      if options.empty? && args.empty?
        custom_default_render
      # Explicit rendering, such as `render :show` or `render action: :show`,
      # but not partials or files (which would include a /)
      elsif options.key?(:action) || args.first.is_a?(Symbol) || (args.first.is_a?(String) && !args.first.include?('/'))
        action_name = options[:action] || args.first.to_s
        render_helper_method(action_name, options)
      # Partials, files and all other cases
      else
        original_render(*args, options)
      end
    end

    def custom_default_render
      render_helper_method(params[:action])
    end

    private

    def render_helper_method action_name, options = {}
      helper_name = "#{self.class.name.gsub('Controller', '')}Helper"
      helper_module = helper_name.constantize

      if helper_module.instance_methods(false).include?(action_name.to_sym)
        content = helper_module.instance_method(action_name).bind(view_context).call
        original_render({ html: Hiccdown::to_html(content).html_safe, layout: !request.format.turbo_stream? }.merge(options))
      else
        original_render({ action: action_name }.merge(options))
      end
    rescue NameError # no helper with that name
      original_render({ action: action_name }.merge(options))
    end
  end
end
