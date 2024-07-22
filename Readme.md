# Hiccdown

Hiccdown is a simple Ruby gem that parses arrays and turns them into HTML strings.

In Rails, it solves a major problem nobody talks about.

The name is a variation on the popular Clojure package [Hiccup](https://github.com/weavejester/hiccup). Hiccdown introduces the same basic functionality in Ruby.

## The problem

If you're used to writing embedded Ruby (those pesky `.erb` files), you may not realize how bad it is.

Consider this template:

```erb
<ul>
  <% [1, 2, 3].each do |i| %>
    <li><%= i %></li>
  <% end %>
</ul>
```

This is *gross*. Embedded Ruby makes you mix your template and your logic. Rails is big on *separation of concerns*, and the above example is the opposite of that. It's "programming in strings", as a former colleague of mine calls it.

This problem is well known in the Clojure world. Logic should be taken care of *before* rendering, not *during*.

Hiccdown takes a datastructure representing your template – which you're free to build up programmatically in any way you like, using the full power of Ruby (`map`, `filter`, `reduce` etc) – and then turns that datastructure into HTML *at the end*. All of this still happens on the server, so you still get all the benefits of pre-processing.

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

### View replacement

**Hiccdown replaces view files.** It modifies intercepts `render` to point to helper methods instead.

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

Hiccdown then calls the `index` and `show` methods on the `ProductsHelper` and renders the corresponding HTML in the browser, inside the application layout, just as you would expect for an `erb` template:

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

Should you call `render` explicitly, however, Hiccdown will not call the corresponding helper method. You remain in control.

You can also call Hiccdown directly in your controller:

```ruby
class FooController < ApplicationController
  def bar
    render html: Hiccdown::to_html([:h1, 'hello world!']).html_safe, layout: true
  end
end
```

(Be careful with `html_safe`.)

Hiccdown *can* be used inside .erb templates, but that’s discouraged:

```erb
<!-- bar.html.erb -->
<%= Hiccdown::to_html([:h1, @text]).html_safe %>
```

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
  end                      # [:a, { href: product_path(p) }, p.title]
end
```

Additional setup is required to teach built-in helper methods how to interpret Hiccdown returned by blocks. First, include the following module in your `ApplicationHelper`:

```ruby
module ApplicationHelper
  include Hiccdown::ViewHelpers
end
```

Now, built-in helpers can process Hiccdown returned by blocks:

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

`content_tag`, `link_to`, `button_to`, and any other helper methods that use `content_tag` support Hiccdown blocks.

Support for form helpers is pending. In the meantime, wrap your form blocks in `content_tag`s:

```ruby
module ProductsHelper
  def form p
    form_with(model: p) do |f|
      content_tag(:div) do
        [:div,
          f.text_field(:title),
          f.text_area(:description),
          [:button, { type: :submit }, 'Submit']]
      end
    end
  end
end
```

## Gradual rollout

You don’t need to replace your views all at once. When there’s no helper method corresponding to a controller action, Rails will render the `erb` template as it normally would. Once you’ve migrated a template, simply delete it to render the helper method instead.

## HTML escape

Hiccdown escapes HTML characters for you in attribute values and primitive children. You can override this behavior by passing `false` as the second parameter:

```ruby
Hiccdown::to_html([:h1, '<script>alert("pwned");</script>'], false)
```

Hiccdown does not escape strings marked as `html_safe`.

## License

MIT
