require 'minitest/autorun'
require 'hiccdown'

class HiccdownTest < Minitest::Test
  def test_convert_tag_with_attrs_but_no_content
    assert_equal '<p class="foo"></p>', Hiccdown::to_html([:p, {class: 'foo'}])
  end

  def test_convert_tag_with_content_but_no_attrs
    assert_equal '<p>foo</p>', Hiccdown::to_html([:p, 'foo'])
  end

  def test_convert_tag_with_content_and_attrs
    assert_equal '<p class="foo">bar</p>', Hiccdown::to_html([:p, {class: 'foo'}, 'bar'])
  end

  def test_convert_tag_with_children
    assert_equal(
      '<p class="foo"><span class="bar">baz</span><a href="#foo">link</a></p>',
      Hiccdown::to_html(
        [:p, {class: 'foo'}, [:span, {class: 'bar'}, 'baz'], [:a, {href: '#foo'}, 'link']]
      )
    )
  end

  def test_standalone_tag_without_attrs
    assert_equal '<img/>', Hiccdown::to_html([:img])
  end

  def test_array_of_children
    assert_equal '<div><img/></div>', Hiccdown::to_html([:div, [[:img]]])
  end

  def test_escape
    assert_equal '<div class="foo&quot;bar">&lt;baz&gt;</div>', Hiccdown::to_html([:div, {class: 'foo"bar'}, '<baz>'])
  end

  def test_no_escape
    assert_equal '<div class="foo"bar"><baz></div>', Hiccdown::to_html([:div, {class: 'foo"bar'}, '<baz>'], false)
  end

  def test_filters_out_nil
    structure = [
      :div,
      'foo',
      if false
        'bar'
      end
    ]

    assert_equal('<div>foo</div>', Hiccdown::to_html(structure))
  end
end
