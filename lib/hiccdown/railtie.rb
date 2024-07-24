module Hiccdown
  class Railtie < Rails::Railtie
    initializer 'hiccdown.action_controller' do
      ActiveSupport.on_load(:action_controller) do
        include CustomViewRendering

        # Per https://stackoverflow.com/a/78783866/1371131
        ActionController::Renderers.add :hiccdown do |src, options|
          render({ html: Hiccdown.to_html(src).html_safe }.merge(options))
        end
      end
    end
  end

  class Renderable
    def initialize(helper_module, action_name)
      @helper_module = helper_module
      @action_name = action_name
    end

    # This is the view-bound view_context. Needed for `content_for` to work
    # properly in helper, see https://stackoverflow.com/a/78783866/1371131
    def render_in(view_context)
      content = @helper_module.instance_method(@action_name).bind_call(view_context)

      Hiccdown::to_html(content)
    end

    def format
      :html
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
      helper_name = "#{controller_name.capitalize}Helper"

      unless Object.const_defined?(helper_name)
        return original_render({ action: action_name }.merge(options))
      end

      helper_module = helper_name.constantize

      if helper_module.instance_methods(false).include?(action_name.to_sym)
        original_render(
          Hiccdown::Renderable.new(helper_module, action_name),
          { layout: !request.format.turbo_stream? }.merge(options)
        )
      else
        original_render({ action: action_name }.merge(options))
      end
    end
  end
end
