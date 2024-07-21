# Hiccdown

Hiccdown is a very simple gem that parses Ruby arrays and turns them into HTML strings.

The name is a variation on the popular Clojure package [Hiccup](https://github.com/weavejester/hiccup). Hiccdown introduces the same (?) functionality in Ruby.

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

Delete your view file. In your controller action, do:

```ruby
class FooController < ApplicationController
  def bar
    render html: Hiccdown::to_html([:h1, 'hello world!']).html_safe
  end
end
```

(Be careful with `html_safe`.)

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

## License

MIT
