# Hiccdown

Hiccdown is a simple Ruby gem that parses arrays and turns them into HTML strings.

In Rails, it solves a major problem nobody talks about.

The name is a variation on the popular Clojure package [Hiccup](https://github.com/weavejester/hiccup). Hiccdown introduces the same basic functionality in Ruby (with some extensions, see below).

## The problem

If you’re used to writing embedded Ruby (those pesky `.erb` files), you may not realize how bad it is.

Consider this template:

```erb
<ul>
  <% [1, 2, 3].each do |i| %>
    <li><%= i %></li>
  <% end %>
</ul>
```

This is *gross*. Embedded Ruby makes you mix your template and your logic. Rails is big on *separation of concerns*, and the above example is the opposite of that. It’s “programming in strings”, as a former colleague of mine calls it.

The fundamental mistake is that of forcing the language in charge of assembling and rendering the template – in this case, Ruby – *into the template itself*. Ruby should be in control; ‘above’ the template, as it were. Instead, it’s demoted to living inside its own creation, resurfacing only through strange interpolative outgrowths.

This problem is well known in the Clojure world. Logic should be taken care of *before* rendering, not *during*.

Hiccdown takes a datastructure representing your template – which you’re free to build up programmatically in any way you like, using the full power of Ruby (`map`, `filter`, `reduce` etc) – and then turns that datastructure into HTML *at the end*. All of this still happens on the server, so you still get all the benefits of pre-processing.

Compare the above `erb` syntax with this simple but functionally equivalent Hiccdown syntax:

```ruby
[:ul, [1, 2, 3].map { |i| [:li, i] }]
```

## Benefits

Here are some of the benefits of Hiccdown:

1. Clean separation of logic and presentation – never write HTML again
2. More concise, Ruby-native syntax
3. Easier programmatic manipulation of content – data is easier to traverse and manipulate than HTML strings
4. Simplified post-processing without additional parsing libraries
5. Reduced risk of HTML-injection vulnerabilities
6. Better composability and reusability of components
7. Easier to generate dynamic structures
8. Enhanced static analysis capabilities

Once you understand these benefits, you’ll realize, for example, that Rails having *both* helper methods *and* view partials has always been a code smell – see below.

## Installation

In your Gemfile:

```ruby
gem 'hiccdown'
```

Then `$ bundle`.

## Usage in Ruby

The original Hiccup [explanation](https://github.com/weavejester/hiccup?tab=readme-ov-file#syntax) applies:

> The first [item] of the [array] is used as the element name. The second [item] can optionally be a map, in which case it is used to supply the element's attributes. Every other [item] is considered part of the [element]'s body.

```ruby
# plain
Hiccdown::to_html [:h1, 'hello world']
# => '<h1>hello world</h1>'

# nested elements
Hiccdown::to_html [:div, [:h1, 'hello world']]
# => '<div><h1>hello world</h1></div>'

# nested siblings
Hiccdown::to_html [:div, [:h1, 'hello world'], [:h2, 'hello again']]
# => '<div><h1>hello world</h1><h2>hello again</h2></div>'

# attributes
Hiccdown::to_html [:h1, {class: 'heading big'}, 'hello world']
# => '<h1 class="heading big">hello world</h1>'

# children as arrays
Hiccdown::to_html [:ul, [[:li, 'first'], [:li, 'second']]]
# => '<ul><li>first</li><li>second</li></ul>'
#
# This is equivalent to writing:
Hiccdown::to_html [:ul, [:li, 'first'], [:li, 'second']]
# So why use it? So you can use methods that return arrays inside your hiccdown
# structure without having to use the splat operator every time:
Hiccdown::to_html [:ul, ['first', 'second'].map { |i| [:li, i] }]
# => '<ul><li>first</li><li>second</li></ul>'
```

## Usage in Rails

Include the following module in your `ApplicationHelper`:

```ruby
module ApplicationHelper
  include Hiccdown::ViewHelpers
end
```

### View replacement

**Hiccdown replaces view files.** It intercepts `render` to point to helper methods instead.

For instance, picture a `ProductsController` with an `index` and a `show` action:

```ruby
class ProductsController < ApplicationController
  def index
    @products = Product.all
  end

  def show
    @product = Product.find(params[:id])
  end
end
```

Hiccdown then calls the `index` and `show` methods on the `ProductsHelper`, turns the return value into HTML, and renders it in the browser, inside the application layout, just as you would expect for an `erb` template:

```ruby
module ProductsHelper
  def index
    [:ul, @products.map { |p| [:li, p.title] }]
    # => Renders '<ul><li>…</li>…</ul>'
  end

  def show
    [:div
      [:h1, @product.title]
      [:span, @product.description]]
    # => Renders '<div><h1>…</h1><span>…</span></div>'
  end
end
```

You can also render Hiccdown directly in your controller:

```ruby
class FooController < ApplicationController
  def bar
    render hiccdown: [:h1, 'hello world!']
  end
end
```

Hiccdown *can* be used inside .erb templates, but that’s discouraged:

```erb
<!-- bar.html.erb -->
<%= Hiccdown::to_html([:h1, @text]).html_safe %>
```

(Be careful with `html_safe`.)

### Usage with additional helper methods

Since Hiccdown code lives inside helpers anyway, simply use additional helper methods in your Hiccdown code:

```ruby
module ProductsHelper
  def index
    [:ul, @products.map { |p| product(p) }] # calls `product` method below
  end

  def show
    [:div
      [:h1, @product.title]
      [:span, @product.description]]
  end

  # This would traditionally live in a _product.html.erb partial
  def product p
    [:li, p.title]
  end
end
```

As you can see, Hiccdown eliminates the need for view *partials*, as well. Again, that both partials *and* helper methods exist in Rails has always been a code smell – it’s a consequence of the wider problem that Rails does not properly separate logic and rendering. This fudge leads to situations where, for instance, you’re not sure if you should make a partial that calls helper methods or create a helper method that uses `content_tag`s.

### Using existing Rails helpers

You can continue using Rails’s built-in helper methods such as `link_to`:

```ruby
module ProductsHelper
  def product p
    [:li,
      link_to(p.title, p)] # functionally equivalent to
  end                      # [:a, { href: url_for(p) }, p.title]
end
```

Built-in helper methods can process Hiccdown returned by blocks:

```ruby
module ProductsHelper
  def product p
    [:li,
      link_to(p) do
        [:h2, p.title]
      end]
  end
end
```

However, rather than use built-in helpers that render HTML, you are encouraged to just use Hiccdown replacements whenever possible. In many cases, nesting Hiccdown structures lets you avoid blocks altogether:

```ruby
[:a, { href: url_for(p) }, # instead of link_to
  [:h2, p.title]]
```

`link_to`, `button_to`, `content_tag`, and all other built-in helper methods for rendering markup should support Hiccdown blocks. Form helpers support them as well:

```ruby
module ProductsHelper
  def form p
    form_with(model: p) do |f|
      [:div,
        f.text_field(:title),
        f.text_area(:description),
        [:button, { type: :submit }, 'Submit']]
    end
  end
end
```

### Scoping

Computations should generally precede the building of a Hiccdown structure itself. Remember, these are all just helper methods, so as long as your method returns Hiccdown, any valid Ruby code works:

```ruby
def product p
  total_sold = product.sales.map(&:total).reduce(&:+)

  [:li, p.title,
    [:strong, 'Sold: ', total_sold]] # total_sold can also be a separate method altogether
end
```

But sometimes, you want to perform computations *within* a Hiccdown structure. Hiccdown ships with a simple method called `scope`:

```ruby
def product p
  [:li, p.title,
    scope do
      total_sold = product.sales.map(&:total).reduce(&:+)

      [:strong, 'Sold: ', total_sold]
    end]
end
```

`scope` accepts arbitrary arguments for easy variable setup:

```ruby
scope(1, 2, 3) do |a, b, c|
  # Instead of
  # a = 1
  # b = 2
  # c = 3
end
```

Outside of Rails, `scope` is available on the Hiccdown module: `Hiccdown::scope`

### Gradual rollout

You don’t need to replace your views all at once. When there’s no helper method corresponding to a controller action, Rails will render the `erb` template as it normally would. Once you’ve migrated a template, simply delete it.

In addition, you can still call `render` in your helpers. So, when a view renders a partial, you can continue to `render` it in your helper until you’ve migrated the partial itself. For example:

```ruby
# ProductsHelper
def index
  [:div,
    [:h1, 'Products'],
    render(@products)]
end
```

```html
<!-- app/views/products/_product.html.erb -->
<h1><%= product.title %></h1>
```

Then, migrate the `_product.html.erb` partial into a helper method called `product` in the same module and update the `index` method accordingly:

```ruby
def index
  [:div,
    [:h1, 'Products'],
    # Invoke `product` instead of `render`
    @products.map { |p| product(p) }]
end

# This replaces _product.html.erb
def product p
  [:h1, p.title]
end
```

Lastly, delete `_product.html.erb`.

### Usage with turbo streams

Where previously you might render a turbo stream like this:

```ruby
turbo_stream.update(@product, partial: 'products/product', locals: { product: @product })
```

You now pass Hiccdown by invoking the helper method that replaces the partial:

```ruby
turbo_stream.update(@product, hiccdown: product(@product)
```

Or pass a Hiccdown structure directly:

```ruby
turbo_stream.update(@product, hiccdown: [:h1, @product.title])
```

## HTML escape

Hiccdown escapes HTML characters in attribute values and primitive children. You can override this behavior by passing `false` as the second parameter:

```ruby
Hiccdown::to_html([:h1, '<script>alert("pwned");</script>'], false)
```

Hiccdown does not escape strings marked as `html_safe`. This can be useful when rendering HTML entities:

```ruby
[:p,
  'foo',
  ' &middot '.html_safe,
  'bar']

# => Browser renders this as 'foo · bar'
```

## Hiccup extensions

For convenience, Hiccdown extends Hiccup in three ways:

1. Deeply nested attribute hashes result in hyphenated attribute keys. This is useful for constructing data attributes. For example:

    ```ruby
    Hiccdown::to_html([:div, { data: { foo: { bar: 'baz' }, fuzz: 'buzz' } }])
    # => '<div data-foo-bar="baz" data-fuzz="buzz"></div>'
    ```

2. Array attribute values are concatenated with a space (after each being cast to a string and escaped). `nil` and empty strings are ignored. This is useful for programmatically building class attributes:

    ```ruby
    Hiccdown::to_html([:div, { class: ['foo', :bar, nil, '', 1] }])
    # => '<div class="foo bar 1"></div>'
    ```

Of course, these first two extensions can be mixed:

```ruby
Hiccdown::to_html([:div, { data: { foo: ['bar', :baz] } }])
# => '<div data-foo="bar baz"></div>'
```

3. To get top-level siblings, ie elements without a parent, wrap them in an array. The elements can be arrays and/or strings and will simply be concatenated:

```ruby
Hiccdown::to_html([[:div, 'foo'], [:div, 'bar']])
# => '<div>foo</div><div>bar</div>'

Hiccdown::to_html(['foo', [:div, 'bar']])
# => 'foo<div>bar</div>'
```

## Todos

- Could the application layout live in ApplicationHelper#layout?
- How to use this with turbo streams?
- Is there a way to teach user-built helpers how to process Hiccdown? Or maybe intercepting `capture` already took care of this?
- Building new components:

    As you can see above, making a component is as easy as writing a helper method.

    An additional benefit of using these methods is that nesting is more concise than with blocks and `yield`.

    ```ruby
    def foo bar, *children
      # instead of block, just pass more args
      # and then maybe Hiccdown should come with its own form component?
    end
    ```

- Make sure you can call methods from other helpers
- Bug: redirects result in two additional requests, the first of which is a turbo-stream request that renders nothing, thus (presumably) prompting the browser to make another request for the same resource.
