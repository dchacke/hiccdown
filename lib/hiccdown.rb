require 'cgi'
require 'active_support/core_ext/string/output_safety'
require 'action_view'

module Hiccdown
  module ViewHelpers
    def self.included(base)
      base.prepend(MethodOverrides)
    end

    def scope *args, &block
      Hiccdown::scope(*args, &block)
    end

    module MethodOverrides
      def self.prepended(base)
        # `capture` is at the root of seemingly all Rails methods tasked with
        # rendering content, including `content_tag` and `tag`, which in turn
        # are used for `link_to`, `form_for`, etc.
        define_method(:capture) do |*args, **kwargs, &block|
          if block
            super(*args, **kwargs) do |*brgs, **jwargs|
              result = block.call(*brgs, *jwargs)
              result.is_a?(Array) ? Hiccdown::to_html(result).html_safe : result
            end
          else
            super(*args, **kwargs)
          end
        end
      end
    end
  end

  def self.scope *args, &block
    block.call(*args)
  end

  def self.standalone_tags
    Set.new([:area, :base, :br, :col, :command, :embed, :hr, :img, :input, :keygen, :link, :menuitem, :meta, :param, :source, :track, :wbr])
  end

  def self.to_html structure, escape = true
    if structure.is_a? Hash
      structure.reduce([]) do |acc, (key, val)|
        acc + [[key.to_s, '="', self.maybe_escape(val.to_s, escape), '"'].join]
      end.join(' ')
    elsif structure.is_a? Array
      if structure.first.is_a?(Array)
        return structure.map { |s| to_html(s, escape) }.join
      end

      if structure[1].is_a? Hash
        tag, attrs, *children = structure.map { |s| to_html(s, escape) }
        tag_and_attrs = structure[1].any? ? [tag, ' ', attrs].join : tag
      else
        tag, *children = structure.map { |s| to_html(s, escape) }
      end

      if standalone_tags.include? tag.to_sym
        ['<', tag_and_attrs || tag, '/>'].join
      else
        ['<', tag_and_attrs || tag, '>', children.join, '</', tag, '>'].join
      end
    else
      self.maybe_escape(structure.to_s, escape)
    end
  end

  def self.maybe_escape escapable, escape
    if escape && !escapable.html_safe?
      CGI::escapeHTML(escapable)
    else
      escapable
    end
  end
end

if defined?(Rails)
  require 'hiccdown/railtie'
end
