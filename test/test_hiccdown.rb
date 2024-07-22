require 'minitest/autorun'
require 'hiccdown'
require 'active_support/core_ext/string/output_safety'

class HiccdownTest < Minitest::Test
  class TestHelper
    include ActionView::Helpers
    include Hiccdown::ViewHelpers
  end

  def setup
    @helper = TestHelper.new
  end

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

  def test_no_escape_when_marked_html_safe
    assert_equal('<div>&lt;this is escaped&gt;<span><but this isn’t></span></div>', Hiccdown::to_html([:div, '<this is escaped>', [:span, '<but this isn’t>'.html_safe]]))
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

  # Testing that Rails helper methods are properly intercepted
  # content_tag
  def test_content_tag_without_block
    result = @helper.content_tag(:span, 'foo')
    assert_equal %{<span>foo</span>}, result
  end

  def test_content_tag_with_regular_block
    result = @helper.content_tag(:span) do
      "foo"
    end

    assert_equal %{<span>foo</span>}, result
  end

  def test_content_tag_with_hiccdown_block
    result = @helper.content_tag(:div) do
      [:span, "Home"]
    end

    assert_equal %{<div><span>Home</span></div>}, result
  end

  # link_to
  def test_link_to_without_block
    result = @helper.link_to('foo', 'bar')
    assert_equal %{<a href="bar">foo</a>}, result
  end

  def test_link_to_with_regular_block
    result = @helper.link_to('foo') do
      'bar'
    end

    assert_equal %{<a href="foo">bar</a>}, result
  end

  def test_link_to_with_hiccdown_block
    result = @helper.link_to('foo') do
      [:span, 'bar']
    end

    assert_equal %{<a href="foo"><span>bar</span></a>}, result
  end

  # button_to
  def test_button_to_without_block
    result = @helper.button_to('foo', 'bar')
    assert_equal %{<form class="button_to" method="post" action="bar"><input type="submit" value="foo" /></form>}, result
  end

  def test_button_to_with_regular_block
    result = @helper.button_to('foo') do
      'bar'
    end

    assert_equal %{<form class="button_to" method="post" action="foo"><button type="submit">bar</button></form>}, result
  end

  def test_button_to_with_hiccdown_block
    result = @helper.button_to('foo') do
      [:span, 'bar']
    end

    assert_equal %{<form class="button_to" method="post" action="foo"><button type="submit"><span>bar</span></button></form>}, result
  end
end
