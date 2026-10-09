module Hiccdown
  class Railtie < Rails::Railtie
    initializer 'hiccdown.action_controller' do
      ActiveSupport.on_load(:action_controller) do
        include CustomViewRendering
        include LayoutRendering

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

      Hiccdown.to_html(content)
    end

    def format
      :html
    end
  end

  # Stands in for a layout file, as `<Name>Helper#layout`. Rails renders it
  # like one, with a block that yields the page's content or, given a name,
  # its `content_for` section, so `yield` and `yield(:title)` work as they
  # do in an ERB layout.
  class Layout
    # The block says whether a layout file of the same name exists too, which
    # the helper takes precedence over.
    def self.for name, logger = nil
      helper_module = "#{name.camelize}Helper".safe_constantize

      unless helper_module.is_a?(Module) && helper_module.instance_methods(false).include?(:layout)
        return nil
      end

      layout = new(helper_module)

      if block_given? && yield
        logger&.warn "Hiccdown: #{layout.identifier} takes precedence over the layout file layouts/#{name}, which can be deleted."
      end

      layout
    end

    def initialize helper_module
      @helper_module = helper_module
    end

    def render view, _locals, &block
      content = @helper_module.instance_method(:layout).bind_call(view, &block)
      html = Hiccdown.to_html(content)

      # Without a doctype, browsers render the page in quirks mode, so
      # Hiccdown adds it rather than have every layout spell it out.
      if content.is_a?(Array) && content.first == :html
        html = "<!DOCTYPE html>#{html}"
      end

      html.html_safe
    end

    def identifier
      "#{@helper_module.name}#layout"
    end

    alias_method :virtual_path, :identifier
  end

  module LayoutRendering
    private

    # Unless told otherwise, Rails looks for a layout named after the
    # controller, then after each of its parents, through the lookup context's
    # `find_all`. Answering those lookups with helper layouts where they exist
    # keeps that order, so a controller's own layout file still comes before
    # the application's helper layout while views move over gradually.
    def _default_layout lookup_context, *args
      super(LayoutLookup.new(lookup_context, logger), *args)
    end

    # Named layouts, as in `layout 'admin'` or `render layout: 'admin'`.
    def _normalize_layout value
      value = super

      if value.is_a?(String) && value.start_with?('layouts/')
        Layout.for(value.delete_prefix('layouts/'), logger) { lookup_context.exists?(value) } || value
      else
        value
      end
    end
  end

  class LayoutLookup < SimpleDelegator
    def initialize lookup_context, logger
      super(lookup_context)
      @logger = logger
    end

    def find_all name, prefixes = [], *rest
      templates = super

      if prefixes == ['layouts']
        layout = Layout.for(name, @logger) { templates.any? }
        layout ? [layout] : templates
      else
        templates
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
      # When a template is given but doesn’t exist. Useful for gems like High Voltage
      elsif options.key?(:template) && !view_context.lookup_context.template_exists?(options[:template])
        action_name = options[:template].split('/').last
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
      helper_name = "#{controller_path.camelize}Helper"

      unless Object.const_defined?(helper_name)
        return original_render({ action: action_name }.merge(options))
      end

      helper_module = helper_name.constantize

      if helper_module.instance_methods(false).include?(action_name.to_sym)
        original_render(
          Hiccdown::Renderable.new(helper_module, action_name),
          options
        )
      else
        original_render({ action: action_name }.merge(options))
      end
    end
  end
end
