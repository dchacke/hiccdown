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

    initializer 'hiccdown.action_mailer' do
      ActiveSupport.on_load(:action_mailer) do
        # Prepended, since ActionMailer::Base defines the methods it overrides
        prepend MailerRendering
        include LayoutRendering
      end
    end
  end

  # An action's helper method's result, which the controller computes before
  # rendering it, so it can decide the format.
  class Renderable
    attr_reader :format

    def initialize(content, format)
      @content = content
      @format = format
    end

    def render_in(_view_context)
      Hiccdown.to_html(@content)
    end

    # Whether content is one or more turbo streams, in Hiccdown or as
    # turbo-rails' `turbo_stream` helper renders them.
    def self.turbo_streams? content
      case content
      when Array
        if content.first.is_a?(Symbol)
          content.first == :'turbo-stream'
        else
          content.any? && content.all? { |c| turbo_streams?(c) }
        end
      when String
        content.lstrip.start_with?('<turbo-stream')
      else
        false
      end
    end
  end

  # Stands in for a layout file, as `<Name>Helper#layout`. Rails renders it
  # like one, with a block that yields the page's content or, given a name,
  # its `content_for` section, so `yield` and `yield(:title)` work as they
  # do in an ERB layout.
  class Layout
    # Helper layouts are HTML, so they only wrap HTML, not turbo streams or
    # other formats, for which Rails would otherwise find no layout.
    def self.formats? formats
      Array(formats).first == :html
    end

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
      if content.is_a?(Array) && content.first.is_a?(Symbol) && content.first.to_s[/\A[^#.]*/] == 'html'
        html = "<!DOCTYPE html>#{html}"
      end

      html.html_safe
    end

    def identifier
      "#{@helper_module.name}#layout"
    end

    alias_method :virtual_path, :identifier
  end

  # Stands in for an email's HTML template, as `<Mailer>Helper#<action>`,
  # which Rails renders like a template file, layout and all.
  class Template
    def self.for path, name
      helper_module = "#{path.camelize}Helper".safe_constantize

      if helper_module.is_a?(Module) && helper_module.instance_methods(false).include?(name.to_sym)
        new(helper_module, name)
      end
    end

    def initialize helper_module, name
      @helper_module = helper_module
      @name = name
    end

    def render view, _locals, &_block
      Hiccdown.to_html(@helper_module.instance_method(@name).bind_call(view)).html_safe
    end

    def format
      :html
    end

    def identifier
      "#{@helper_module.name}##{@name}"
    end

    alias_method :virtual_path, :identifier
  end

  # A mailer's helper is named after it, like a controller's, so the HTML
  # part of `UserMailer#welcome` comes from `UserMailerHelper#welcome`, if it
  # has one. Templates in other formats, such as text, still come from files.
  module MailerRendering
    private

    def each_template paths, name, &block
      template = hiccdown_template(paths, name)
      return super unless template

      others = lookup_context.find_all(name, paths).reject { |t| t.format == :html }
      [template, *others].uniq(&:format).each(&block)
    end

    # As in `mail { |format| format.html }`, which renders the action by name.
    def render *args
      options = args.last.is_a?(Hash) ? args.last : {}
      name = options[:action] || args.first

      if (name.is_a?(String) || name.is_a?(Symbol)) && !name.to_s.include?('/') &&
         lookup_context.formats.first == :html &&
         (template = hiccdown_template(_prefixes, name.to_s))
        super(template: template, formats: [:html], **options.except(:action))
      else
        super
      end
    end

    def hiccdown_template paths, name
      Array(paths).lazy.filter_map { |path| Template.for(path, name) }.first
    end
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
    # Rails resolves a proc once it knows the format of the response, which
    # decides whether a helper layout applies.
    def _normalize_layout value
      value = super

      if value.is_a?(String) && value.start_with?('layouts/')
        logger = self.logger

        proc do |lookup_context, formats|
          name = value.delete_prefix('layouts/')
          file = lookup_context.exists?(value, [], false, [], formats: formats)

          if Layout.formats?(formats)
            Layout.for(name, logger) { file } || value
          # Other formats get no layout from a helper layout, as from an ERB
          # layout that's only HTML.
          elsif file || !Layout.for(name)
            value
          end
        end
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
      options = rest.last.is_a?(Hash) ? rest.last : {}

      if prefixes == ['layouts'] && Layout.formats?(options[:formats])
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
      # Options that only say how to render the action, such as
      # `render status: :not_found` or `render layout: 'admin'`
      elsif args.empty? && !renders_content?(options)
        render_helper_method(action_name, options)
      # Explicit rendering, such as `render :show` or `render action: :show`,
      # but not partials or files (which would include a /)
      elsif options.key?(:action) || args.first.is_a?(Symbol) || (args.first.is_a?(String) && !args.first.include?('/'))
        render_helper_method((options[:action] || args.first).to_s, options)
      # When a template is given but doesn’t exist. Useful for gems like High Voltage
      elsif options.key?(:template) && !view_context.lookup_context.template_exists?(options[:template])
        render_helper_method(options[:template].split('/').last, options)
      # Partials, files and all other cases
      else
        original_render(*args, options)
      end
    end

    def custom_default_render
      render_helper_method(action_name)
    end

    # The view context that renders an action's helper method, while it
    # does, so the method and the rendering share it.
    def view_context
      @_hiccdown_view_context || super
    end

    # Options that say what to render, besides those of renderers like `json:`
    # and `hiccdown:`.
    CONTENT_OPTIONS = %i[action template partial file inline plain html body renderable].freeze

    private

    def renders_content? options
      options.keys.any? { |key| CONTENT_OPTIONS.include?(key) || ActionController::Renderers::RENDERERS.include?(key) }
    end

    def render_helper_method action_name, options = {}
      helper_name = "#{controller_path.camelize}Helper"

      unless Object.const_defined?(helper_name)
        return original_render({ action: action_name }.merge(options))
      end

      helper_module = helper_name.constantize

      if helper_module.instance_methods(false).include?(action_name.to_sym)
        render_hiccdown(helper_module, action_name, options)
      else
        original_render({ action: action_name }.merge(options))
      end
    end

    # The helper method runs before rendering, so its result can decide the
    # format: turbo streams answer requests that take them as streams, without
    # a layout, and everything else is HTML. It runs in the view context that
    # then renders it, so that `content_for` reaches the layout (see
    # https://stackoverflow.com/a/78783866/1371131).
    def render_hiccdown helper_module, action_name, options
      @_hiccdown_view_context = view_context
      content = helper_module.instance_method(action_name).bind_call(@_hiccdown_view_context)
      stream = formats.include?(:turbo_stream) && Hiccdown::Renderable.turbo_streams?(content)

      original_render(Hiccdown::Renderable.new(content, stream ? :turbo_stream : :html), options)
    ensure
      @_hiccdown_view_context = nil
    end
  end
end
