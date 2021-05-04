require 'minitest/autorun'
require 'hiccdown'

class HiccdownTest < Minitest::Test
  # def test_convert_standalone_tag
  #   assert_equal Hiccdown::to_html([:img]), '<img>'
  # end

  def test_convert_solo_tag
    assert_equal Hiccdown::to_html([:p]), '<p></p>'
  end

  def test_convert_tag_with_attrs_but_no_content
    assert_equal Hiccdown::to_html([:p, {class: 'foo'}]), '<p class="foo"></p>'
  end

  def test_convert_tag_with_content_but_no_attrs
    assert_equal Hiccdown::to_html([:p, 'foo']), '<p>foo</p>'
  end

  def test_convert_tag_with_content_and_attrs
    assert_equal Hiccdown::to_html([:p, {class: 'foo'}, 'bar']), '<p class="foo">bar</p>'
  end

  def test_convert_tag_with_children
    assert_equal(
      Hiccdown::to_html(
        [:p, {class: 'foo'}, [:span, {class: 'bar'}, 'baz'], [:a, {href: '#foo'}, 'link']]
      ),
      '<p class="foo"><span class="bar">baz</span><a href="#foo">link</a></p>'
    )
  end
end
