# Hiccdown

Hiccdown is a very simple gem that parses Ruby arrays and turns them into HTML strings.

The name is a variation on the popular Clojure package [Hiccup](https://github.com/weavejester/hiccup). Hiccdown introduces the same (?) functionality in Ruby.

## Installation

In your Gemfile:

```ruby
gem 'hiccdown'
```

Then `$ bundle`.

## Usage

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

## Usage within Rails

You can either render HTML directly in your controller:

```ruby
class FooController < ApplicationController
  def bar
    render html: Hiccdown::to_html([:h1, 'hello world!']).html_safe, layout: true
  end
end
```

Or, more commonly, in a `.hdml` view:

```ruby
class FooController < ApplicationController
  def bar
    @text = 'Hello, world!'
  end
end
```

```ruby
# bar.hdml
[:h1, @text]
```

`.hdml` views must return a single array. You can use Ruby comments inside them.

Hiccdown *can* be used inside .erb templates, but that’s discouraged:

```erb
<!-- bar.html.erb -->
<%= Hiccdown::to_html([:h1, @text]).html_safe %>
```

(Be careful with `html_safe`.)

Hiccdown shines with datastructures. Concider a common use case, where you iterate over some collection to display a list:

```ruby
class FooController < ApplicationController
  def bar
    @items = ['one', 'two', 'three']
  end
end
```

```ruby
# bar.hdml
[:ul,
  @items.map { |item| [:li, item] }]
```

## Why?

If you're used to writing embedded Ruby (those pesky `.erb` files), you may not realize how bad it is.

Consider this template:

```erb
<ul>
  <% [1, 2, 3].each do |i| %>
    <li><%= i %></li>
  <% end %>
</ul>
```

This is *gross*. Embedded Ruby makes you mix your template and your logic. Rails is big on *separation of concerns*, and the above example is the opposite of that. It's "programming in strings", as a former colleague would call it. This problem is well known in the Clojure world. Logic should be taken care of *before* rendering, not *during*.

Hiccdown makes this happen by taking a datastructure representing your template – which you're free to build up logically in any way you like, using the full power of the Ruby programming language (`map`, `filter`, `reduce` etc) – and then turning that into HTML *at the end*. All of this still happens on the server, so you still get all the benefits of pre-processing.

## HTML escape

Hiccdown escapes HTML characters for you in attribute values and primitive children. You can override this behavior by passing `false` as the second parameter: `Hiccdown::to_html([:h1, '<script>alert("pawned");</script>'], false)`

## License

MIT
