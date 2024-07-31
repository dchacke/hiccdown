require_relative 'test_helper'

class HiccdownTest < Minitest::Test
  def setup
    @helper = TestHelper.new
  end

  def test_convert_empty_tag
    assert_equal '<p></p>', Hiccdown.to_html([:p])
  end

  def test_convert_tag_with_attrs_but_no_content
    assert_equal '<p class="foo"></p>', Hiccdown.to_html([:p, {class: 'foo'}])
  end

  def test_convert_tag_with_content_but_no_attrs
    assert_equal '<p>foo</p>', Hiccdown.to_html([:p, 'foo'])
  end

  def test_convert_tag_with_content_and_attrs
    assert_equal '<p class="foo">bar</p>', Hiccdown.to_html([:p, {class: 'foo'}, 'bar'])
  end

  def test_convert_tag_with_children
    assert_equal(
      '<p class="foo"><span class="bar">baz</span><a href="#foo">link</a></p>',
      Hiccdown.to_html(
        [:p, {class: 'foo'}, [:span, {class: 'bar'}, 'baz'], [:a, {href: '#foo'}, 'link']]
      )
    )
  end

  def test_standalone_tag_without_attrs
    assert_equal '<img/>', Hiccdown.to_html([:img])
  end

  def test_array_of_children
    assert_equal '<div><img/></div>', Hiccdown.to_html([:div, [[:img]]])
  end

  def test_empty_array_of_children
    assert_equal('<div></div>', Hiccdown.to_html([:div, []]))
  end

  def test_escape
    assert_equal '<div class="foo&quot;bar">&lt;baz&gt;</div>', Hiccdown.to_html([:div, {class: 'foo"bar'}, '<baz>'])
  end

  def test_no_escape
    assert_equal '<div class="foo"bar"><baz></div>', Hiccdown.to_html([:div, {class: 'foo"bar'}, '<baz>'], false)
  end

  def test_no_escape_when_marked_html_safe
    assert_equal('<div>&lt;this is escaped&gt;<span><but this isn’t></span></div>', Hiccdown.to_html([:div, '<this is escaped>', [:span, '<but this isn’t>'.html_safe]]))
  end

  def test_filters_out_nil
    structure = [
      :div,
      'foo',
      if false
        'bar'
      end
    ]

    assert_equal('<div>foo</div>', Hiccdown.to_html(structure))
  end

  def test_nested_attrs
    structure = [
      :div,
      {
        foo: :bar,
        data: {
          foo: { bar: :baz },
          bar: 'bazz'
        }
      }
    ]

    assert_equal('<div foo="bar" data-foo-bar="baz" data-bar="bazz"></div>', Hiccdown.to_html(structure))
  end

  def test_array_attr_value_is_concatenated
    structure = [
      :div,
      {
        foo: ['foo', :bar, 'baz', 1],
        bar: 'buz',
        data: {
          baz: ['buzz', :bar],
          bazz: 'fooz'
        }
      }
    ]

    assert_equal('<div foo="foo bar baz 1" bar="buz" data-baz="buzz bar" data-bazz="fooz"></div>', Hiccdown.to_html(structure))
  end

  def test_array_attr_filters_empty_items
    assert_equal('<div class="foo bar"></div>', Hiccdown.to_html([:div, class: ['foo', nil, '', 'bar']]))
  end

  def test_top_level_array_with_array_elements
    assert_equal('<div>foo</div><strong>bar</strong>', Hiccdown.to_html([[:div, 'foo'], [:strong, 'bar']]))
  end

  def test_top_level_array_with_mixed_elements
    assert_equal('foo<strong>bar</strong>', Hiccdown.to_html(['foo', [:strong, 'bar']]))
  end

  def test_top_level_array_with_integer
    assert_equal('0<strong>bar</strong>', Hiccdown.to_html([0, [:strong, 'bar']]))
  end

  def test_top_level_array_with_float
    assert_equal('0.5<strong>bar</strong>', Hiccdown.to_html([0.5, [:strong, 'bar']]))
  end

  # ---------------------------------------------------------------------------

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

  # form_for
  def test_form_for_with_regular_block
    record = Record.new(foo: 'custom value')

    result = @helper.form_for(record) do |f|
      'foo'
    end

    assert_equal %{<form class="new_record" id="new_record" action="/records" accept-charset="UTF-8" method="post"><input name="utf8" type="hidden" value="&#x2713;" autocomplete="off" />foo</form>}, result
  end

  def test_form_for_with_hiccdown_block
    record = Record.new(foo: 'custom value')

    result = @helper.form_for(record) do |f|
      [:strong, 'foo']
    end

    assert_equal %{<form class="new_record" id="new_record" action="/records" accept-charset="UTF-8" method="post"><input name="utf8" type="hidden" value="&#x2713;" autocomplete="off" /><strong>foo</strong></form>}, result
  end

  # form_with
  def test_form_with_with_regular_block
    record = Record.new(foo: 'custom value')

    result = @helper.form_with(model: record) do |f|
      'foo'
    end

    assert_equal %{<form action="/records" accept-charset="UTF-8" method="post"><input name="utf8" type="hidden" value="&#x2713;" autocomplete="off" />foo</form>}, result
  end

  def test_form_with_with_hiccdown_block
    record = Record.new(foo: 'custom value')

    result = @helper.form_with(model: record) do |f|
      [:strong, 'foo']
    end

    assert_equal %{<form action="/records" accept-charset="UTF-8" method="post"><input name="utf8" type="hidden" value="&#x2713;" autocomplete="off" /><strong>foo</strong></form>}, result
  end

  # label
  def test_label_with_regular_block
    record = Record.new(foo: 'custom value')

    result = @helper.form_for(record) do |f|
      f.label :foo do
        'Bar'
      end
    end

    assert_equal %{<form class="new_record" id="new_record" action="/records" accept-charset="UTF-8" method="post"><input name="utf8" type="hidden" value="&#x2713;" autocomplete="off" /><label for="record_foo">Bar</label></form>}, result
  end

  def test_label_with_hiccdown_block
    record = Record.new(foo: 'custom value')

    result = @helper.form_for(record) do |f|
      f.label :foo do
        [:strong, 'Bar']
      end
    end

    assert_equal %{<form class="new_record" id="new_record" action="/records" accept-charset="UTF-8" method="post"><input name="utf8" type="hidden" value="&#x2713;" autocomplete="off" /><label for="record_foo"><strong>Bar</strong></label></form>}, result
  end

  # fields_for
  def test_fields_for_with_regular_block
    record = Record.new(foo: 'custom value')

    result = @helper.form_for(record) do |f|
      f.fields_for(:records) do |g|
        'foo'
      end
    end

    assert_equal %{<form class="new_record" id="new_record" action="/records" accept-charset="UTF-8" method="post"><input name="utf8" type="hidden" value="&#x2713;" autocomplete="off" />foo</form>}, result
  end

  def test_fields_for_with_hiccdown_block
    record = Record.new(foo: 'custom value')

    result = @helper.form_for(record) do |f|
      f.fields_for(:records) do |g|
        [:strong, 'foo']
      end
    end

    assert_equal %{<form class="new_record" id="new_record" action="/records" accept-charset="UTF-8" method="post"><input name="utf8" type="hidden" value="&#x2713;" autocomplete="off" /><strong>foo</strong></form>}, result
  end

  # ---------------------------------------------------------------------------

  def test_scope_standalone
    result = @helper.scope(1, 2, 3) do |a, b, c|
      a + b + c
    end

    assert_equal(6, result)
  end

  def test_scope_within_hiccdown
    structure = [
      :div,
      @helper.scope(1, 2) do |a, b|
        c = a + b
        d = c + 2

        [:span, d]
      end,
      'foo'
    ]

    assert_equal(%{<div><span>5</span>foo</div>}, Hiccdown.to_html(structure))
  end

  def test_scope_on_module
    result = Hiccdown.scope(1, 2, 3) do |a, b, c|
      a + b + c
    end

    assert_equal(6, result)
  end
end
