module Hiccdown
  def standalone_tags
    Set.new(:area, :base, :br, :col, :command, :embed, :hr, :img, :input, :keygen, :link, :menuitem, :meta, :param, :source, :track, :wbr)
  end

  def self.to_html structure
    if structure.is_a? Hash
      structure.reduce([]) do |acc, (key, val)|
        acc + [[key.to_s, '="', val.to_s, '"'].join]
      end.join(' ')
    elsif structure.is_a? Array
      if structure[1].is_a? Hash
        tag, attrs, *children = structure.map { |s| to_html s}
        tag_and_attrs = structure[1].any? ? [tag, ' ', attrs].join : tag
      else
        tag, *children = structure.map { |s| to_html s}
      end

      ['<', tag_and_attrs || tag, '>', children.join, '</', tag, '>'].join
    else
      structure.to_s
    end
  end
end
