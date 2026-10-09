require_relative 'test_helper'

class HiccdownTest < Minitest::Test
  def setup
    @helper = TestHelper.new
  end

  # Forms start with this hidden input of Rails' own, whose attributes come in
  # a different order from one version of Rails to another.
  def utf8_input
    @helper.utf8_enforcer_tag
  end

  def assert_captures_like_rails &block
    rails = Class.new { include ActionView::Context, ActionView::Helpers }.new
    expected = (rails.capture(text: 'foo', &block) rescue $!.class)
    assert_equal expected, (@helper.capture(text: 'foo', &block) rescue $!.class)
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

  def test_empty_array
    assert_equal('', Hiccdown.to_html([]))
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

  # As in Rails: an attribute that's nil is left out, and so is a boolean
  # attribute that's false, since `disabled="false"` would still disable.
  def test_nil_and_false_boolean_attrs_are_left_out
    assert_equal('<input type="text"/>', Hiccdown.to_html([:input, {type: 'text', disabled: false, 'checked' => false, value: nil}]))
  end

  # For other attributes, false is a value.
  def test_false_non_boolean_attrs_are_kept
    assert_equal('<a draggable="false" spellcheck="false" href="/"></a>', Hiccdown.to_html([:a, {draggable: false, spellcheck: false, href: '/'}]))
  end

  # In data and aria attributes, false means something.
  def test_false_nested_attrs_are_kept
    assert_equal('<div data-open="false" aria-hidden="false"></div>', Hiccdown.to_html([:div, {data: {open: false, foo: nil}, aria: {hidden: false}}]))
  end

  # Names can't break out of the tag, whatever they contain.
  def test_attr_names_are_sanitized
    assert_equal('<div x__onmouseover__alert(1)_="y"></div>', Hiccdown.to_html([:div, {'x" onmouseover="alert(1)"' => 'y'}]))
  end

  def test_nested_attr_names_are_sanitized
    assert_equal('<div data-a_b="c"></div>', Hiccdown.to_html([:div, {data: {'a b' => 'c'}}]))
  end

  def test_tag_names_are_sanitized
    assert_equal('<div__script>x</div__script>', Hiccdown.to_html([:'div><script', 'x']))
  end

  # Names that frameworks like Alpine.js use stay as they are.
  def test_attr_names_with_at_and_colon
    assert_equal('<button @click="open = true" :class="x"></button>', Hiccdown.to_html([:button, {'@click' => 'open = true', ':class' => 'x'}]))
  end

  def test_top_level_array_with_array_elements
    assert_equal('<div>foo</div><strong>bar</strong>', Hiccdown.to_html([[:div, 'foo'], [:strong, 'bar']]))
  end

  def test_string_for_first_element
    assert_equal('foo<strong>bar</strong>', Hiccdown.to_html(['foo', [:strong, 'bar']]))
  end

  def test_number_for_first_element
    assert_equal('0<strong>bar</strong>', Hiccdown.to_html([0, [:strong, 'bar']]))
  end

  def test_float_for_first_element
    assert_equal('0.5<strong>bar</strong>', Hiccdown.to_html([0.5, [:strong, 'bar']]))
  end

  # A first element that's nil, such as what an empty block returns, used to
  # be taken for a tag name and rendered as '<>'.
  def test_nil_for_first_element
    assert_equal('<strong>bar</strong>', Hiccdown.to_html([nil, [:strong, 'bar']]))
  end

  # Hiccup's shorthand for ids and classes in the tag
  def test_shorthand_id
    assert_equal('<div id="my-id"></div>', Hiccdown.to_html([:'div#my-id']))
  end

  def test_shorthand_classes
    assert_equal('<div class="my-class another-class"></div>', Hiccdown.to_html([:'div.my-class.another-class']))
  end

  def test_shorthand_id_and_classes
    assert_equal('<div id="my-id" class="my-class another-class"></div>', Hiccdown.to_html([:'div#my-id.my-class.another-class']))
  end

  def test_shorthand_in_any_order
    assert_equal('<div id="my-id" class="my-class another-class"></div>', Hiccdown.to_html([:'div.my-class#my-id.another-class']))
  end

  def test_shorthand_with_attrs
    assert_equal('<div id="override" class="my-class another-class additive"></div>',
      Hiccdown.to_html([:'div#my-id.my-class.another-class', {id: 'override', class: 'additive'}]))
  end

  def test_shorthand_with_class_array
    assert_equal('<div class="a b"></div>', Hiccdown.to_html([:'div.a', {class: ['b', nil]}]))
  end

  def test_shorthand_with_other_attrs_and_children
    assert_equal('<a class="link" href="/x">x</a>', Hiccdown.to_html([:'a.link', {href: '/x'}, 'x']))
  end

  def test_shorthand_with_children
    assert_equal('<p class="lead">Hi</p>', Hiccdown.to_html([:'p.lead', 'Hi']))
  end

  def test_shorthand_on_standalone_tag
    assert_equal('<img class="photo" src="x.png"/>', Hiccdown.to_html([:'img.photo', {src: 'x.png'}]))
  end

  def test_shorthand_with_two_ids
    assert_raises(ArgumentError) { Hiccdown.to_html([:'div#a#b']) }
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

  def test_content_tag_with_empty_hiccdown_block
    result = @helper.content_tag(:div) do
      []
    end

    assert_equal %{<div></div>}, result
  end

  def test_content_tag_with_hiccdown_content
    assert_equal %{<div class="card"><span>Home</span></div>}, @helper.content_tag(:div, [:span, 'Home'], class: 'card')
  end

  def test_content_tag_escapes_hiccdown_content
    assert_equal %{<div><span>&lt;b&gt;</span></div>}, @helper.content_tag(:div, [:span, '<b>'])
  end

  def test_content_tag_without_escaping_hiccdown_content
    assert_equal %{<div><span><b></span></div>}, @helper.content_tag(:div, [:span, '<b>'], nil, false)
  end

  def test_tag_builder_with_hiccdown_content
    assert_equal %{<div><span>Home</span></div>}, @helper.tag.div([:span, 'Home'])
  end

  # A helper of the app's own that yields into a Rails helper, rather than
  # passing the block on.
  def test_helper_yielding_hiccdown_into_content_tag
    def @helper.card
      content_tag(:div, yield, class: 'card')
    end

    assert_equal %{<div class="card"><span>Home</span></div>}, @helper.card { [:span, 'Home'] }
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

  def test_link_to_with_empty_hiccdown_block
    result = @helper.link_to('foo') do
      []
    end

    assert_equal %{<a href="foo"></a>}, result
  end

  def test_link_to_with_hiccdown_name
    assert_equal %{<a href="bar"><span>foo</span></a>}, @helper.link_to([:span, 'foo'], 'bar')
  end

  # render
  def test_render_hiccdown
    assert_equal %{<h1>foo</h1>}, @helper.render(hiccdown: [:h1, 'foo'])
  end

  def test_render_empty_hiccdown
    assert_equal '', @helper.render(hiccdown: [])
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

    assert_equal %{<form class="new_record" id="new_record" action="/records" accept-charset="UTF-8" method="post">#{utf8_input}foo</form>}, result
  end

  def test_form_for_with_hiccdown_block
    record = Record.new(foo: 'custom value')

    result = @helper.form_for(record) do |f|
      [:strong, 'foo']
    end

    assert_equal %{<form class="new_record" id="new_record" action="/records" accept-charset="UTF-8" method="post">#{utf8_input}<strong>foo</strong></form>}, result
  end

  # form_with
  def test_form_with_with_regular_block
    record = Record.new(foo: 'custom value')

    result = @helper.form_with(model: record) do |f|
      'foo'
    end

    assert_equal %{<form action="/records" accept-charset="UTF-8" method="post">#{utf8_input}foo</form>}, result
  end

  def test_form_with_with_hiccdown_block
    record = Record.new(foo: 'custom value')

    result = @helper.form_with(model: record) do |f|
      [:strong, 'foo']
    end

    assert_equal %{<form action="/records" accept-charset="UTF-8" method="post">#{utf8_input}<strong>foo</strong></form>}, result
  end

  # label
  def test_label_with_regular_block
    record = Record.new(foo: 'custom value')

    result = @helper.form_for(record) do |f|
      f.label :foo do
        'Bar'
      end
    end

    assert_equal %{<form class="new_record" id="new_record" action="/records" accept-charset="UTF-8" method="post">#{utf8_input}<label for="record_foo">Bar</label></form>}, result
  end

  def test_label_with_hiccdown_block
    record = Record.new(foo: 'custom value')

    result = @helper.form_for(record) do |f|
      f.label :foo do
        [:strong, 'Bar']
      end
    end

    assert_equal %{<form class="new_record" id="new_record" action="/records" accept-charset="UTF-8" method="post">#{utf8_input}<label for="record_foo"><strong>Bar</strong></label></form>}, result
  end

  # fields_for
  def test_fields_for_with_regular_block
    record = Record.new(foo: 'custom value')

    result = @helper.form_for(record) do |f|
      f.fields_for(:records) do |g|
        'foo'
      end
    end

    assert_equal %{<form class="new_record" id="new_record" action="/records" accept-charset="UTF-8" method="post">#{utf8_input}foo</form>}, result
  end

  def test_fields_for_with_hiccdown_block
    record = Record.new(foo: 'custom value')

    result = @helper.form_for(record) do |f|
      f.fields_for(:records) do |g|
        [:strong, 'foo']
      end
    end

    assert_equal %{<form class="new_record" id="new_record" action="/records" accept-charset="UTF-8" method="post">#{utf8_input}<strong>foo</strong></form>}, result
  end

  # capture hands its arguments to the block as Rails does, which passes
  # keywords on as keywords from Rails 8.1 and as a hash before.
  def test_capture_passes_keywords_to_block
    assert_captures_like_rails { |text:| text }
  end

  def test_capture_passes_keywords_to_block_as_hash
    assert_captures_like_rails { |options| options[:text] }
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
