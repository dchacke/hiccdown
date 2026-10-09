require 'cgi'
require 'active_support/core_ext/string/output_safety'
require 'action_view'

module Hiccdown
  module ViewHelpers
    def self.included(base)
      base.prepend(ViewHelperOverrides)
      ActionView::Helpers::RenderingHelper.prepend(RenderingHelperOverrides)
      ActionView::Helpers::TagHelper::TagBuilder.prepend(TagBuilderOverrides)
    end

    def scope *args, &block
      Hiccdown.scope(*args, &block)
    end

    module ViewHelperOverrides
      def self.prepended(base)
        # `capture` is at the root of seemingly all Rails methods tasked with
        # rendering content, including `content_tag` and `tag`, which in turn
        # are used for `link_to`, `form_for`, etc.
        define_method(:capture) do |*args, **kwargs, &block|
          if block
            super(*args, **kwargs) do |*brgs, **jwargs|
              result = block.call(*brgs, **jwargs)
              result.is_a?(Array) ? Hiccdown.to_html(result).html_safe : result
            end
          else
            super(*args, **kwargs)
          end
        end
      end
    end

    module RenderingHelperOverrides
      def self.prepended(base)
        # This teaches the view renderer (which is different from the controller renderer,
        # h/t https://stackoverflow.com/questions/78801079/rails-custom-renderer-for-turbo-stream?noredirect=1#comment138933498_78801079)
        # to accept a `:hiccdown` option, thus enabling the rendering of hiccdown in turbo-stream
        # actions as well:
        # `turbo_stream.update(..., hiccdown: [:h1, 'hello world'])
        define_method(:render) do |options = {}, locals = {}, &block|
          if options.is_a?(Hash) && options.key?(:hiccdown)
            Hiccdown.to_html(options[:hiccdown]).html_safe
          else
            super(options, locals, &block)
          end
        end
      end
    end

    module TagBuilderOverrides
      def self.prepended(base)
        # Content given as an argument rather than a block, as in
        # `content_tag(:div, [:span, 'foo'])`, `tag.div(...)`,
        # `link_to([:span, 'foo'], path)` or a helper that yields into one of
        # them, skips `capture` and ends up here.
        define_method(:content_tag_string) do |name, content, options, escape = true|
          content = Hiccdown.to_html(content, escape).html_safe if content.is_a?(Array)
          super(name, content, options, escape)
        end
      end
    end
  end

  def self.scope *args, &block
    block.call(*args)
  end

  STANDALONE_TAGS = Set.new([:area, :base, :br, :col, :command, :embed, :hr, :img, :input, :keygen, :link, :menuitem, :meta, :param, :source, :track, :wbr]).freeze

  def self.standalone_tags
    STANDALONE_TAGS
  end

  # Characters a tag or attribute name can't contain, since they'd end it.
  UNSAFE_NAME_CHARACTERS = /[\s"'<>\/=\x00-\x1f\x7f]/

  # Names aren't content, so they're made safe whether or not content is
  # escaped, as Rails does.
  def self.name_escape name
    name.to_s.gsub(UNSAFE_NAME_CHARACTERS, '_')
  end

  def self.process_attributes(hash, prefix = nil, escape)
    hash.flat_map do |key, value|
      attribute_key = name_escape(prefix ? "#{prefix}-#{key}" : key)

      # As in Rails, nil leaves an attribute out, and so does false, since
      # `disabled="false"` would still disable. In nested attributes, like
      # data and aria ones, false means something, so it stays.
      if value.nil? || (value == false && !prefix)
        []
      elsif value.is_a?(Hash)
        process_attributes(value, attribute_key, escape)
      elsif value.is_a?(Array)
        value_str = value
          .reject { |v| v.to_s == '' }
          .map { |v| maybe_escape(v.to_s, escape) }
          .join(' ')

        [%{#{attribute_key}="#{value_str}"}]
      else
        value_str = maybe_escape(value.to_s, escape)
        [%{#{attribute_key}="#{value_str}"}]
      end
    end
  end

  def self.to_html structure, escape = true
    if structure.is_a? Hash
      self.process_attributes(structure, nil, escape).join(' ')
    elsif structure.is_a? Array
      # Empty arrays end up here too, as no siblings, so they render as an
      # empty string rather than nil, which callers can mark `html_safe`.
      unless structure.first.is_a?(Symbol)
        return structure.map { |s| to_html(s, escape) }.join
      end

      structure = expand_shorthand(structure) if structure.first.to_s.match?(/[#.]/)

      tag = name_escape(structure.first)

      if structure[1].is_a? Hash
        attrs = process_attributes(structure[1], nil, escape).join(' ')
        children = structure.drop(2)
      else
        attrs = ''
        children = structure.drop(1)
      end

      tag_and_attrs = attrs.empty? ? tag : [tag, ' ', attrs].join
      children = children.map { |s| to_html(s, escape) }

      if standalone_tags.include? tag.to_sym
        ['<', tag_and_attrs, '/>'].join
      else
        ['<', tag_and_attrs, '>', children.join, '</', tag, '>'].join
      end
    else
      self.maybe_escape(structure.to_s, escape)
    end
  end

  # Hiccup's shorthand for ids and classes, as in `:'div#main.big.red'`, in
  # any order after the tag name. An id in the attributes takes precedence,
  # and their classes are added to the shorthand's.
  def self.expand_shorthand structure
    tag, *parts = structure.first.to_s.split(/(?=[#.])/)
    ids, classes = parts.partition { |part| part.start_with?('#') }

    if ids.size > 1
      raise ArgumentError, "#{structure.first.inspect} has more than one id"
    end

    attrs = {}
    attrs[:id] = ids.first.delete_prefix('#') if ids.any?
    attrs[:class] = classes.map { |c| c.delete_prefix('.') } if classes.any?

    rest = structure.drop(1)

    if rest.first.is_a?(Hash)
      rest.shift.each do |key, value|
        key = key.to_sym if %w[id class].include?(key.to_s)

        if key == :class && attrs[:class]
          attrs[:class] += Array(value)
        else
          attrs[key] = value
        end
      end
    end

    [tag.to_sym, attrs, *rest]
  end

  def self.maybe_escape escapable, escape
    if escape && !escapable.html_safe?
      CGI.escapeHTML(escapable)
    else
      escapable
    end
  end
end

if defined?(Rails)
  require 'hiccdown/railtie'
end
