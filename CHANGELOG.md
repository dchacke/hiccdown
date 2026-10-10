# Changelog

## 2.1.0

### New

- Mailers render HTML from helper methods, as controllers do: the HTML part of `UserMailer#welcome` comes from `UserMailerHelper#welcome`, and `layout 'mailer'` can live in `MailerHelper#layout`. A helper method takes precedence over an HTML template of the same name, and `mail { |format| format.html }` uses it too. Text parts and their layouts still come from templates, so an email can have its HTML from a helper and its text from a file.
- Mailers don't include `ApplicationHelper`, so include `Hiccdown::ViewHelpers` in a helper they use, such as `MailerHelper`, for helpers with blocks, like `content_for`, to take Hiccdown there.

## 2.0.0

Compared with 1.5.4.

### Breaking changes

- Attributes that are `nil` are left out. They used to render empty: `class: nil` gave `class=""`, and `data: { foo: nil }` gave `data-foo=""`.
- Boolean attributes, like `disabled`, `checked` and `selected`, are left out when they're `false`, as in Rails. They used to render `disabled="false"`, which still disabled. Other attributes, like `draggable` or data attributes, still render `"false"`.
- `Hiccdown.to_html([])` returns `''` instead of `nil`.
- Characters that can't be in a tag or attribute name, like spaces, quotes, `<`, `>`, `/` and `=`, become underscores, so names can't break out of the tag, even when they come from user input.
- Hiccdown requires Rails 7.0 to 8.1 and Ruby 2.7 or later. 1.5.4 didn't declare its dependencies.

### New

- Layouts can live in helper methods called `layout`. A layout named X lives in `XHelper#layout`, as it would in `layouts/X.html.erb`: `ApplicationHelper#layout` for the application, `ProductsHelper#layout` for `ProductsController`, `AdminHelper#layout` for `layout 'admin'`. `yield` and `yield(:title)` work as in an ERB layout, and Hiccdown adds `<!DOCTYPE html>` to layouts whose root is `:html`. Layout files keep working, so you can move over gradually; where a layout exists both ways, the helper method is used and a warning is logged. Helper layouts only wrap HTML, so turbo streams and Turbo's frame layout are left be.
- An action's helper method can answer with turbo streams. When it returns one or more, in Hiccdown or from `turbo_stream`, and the request takes turbo streams, as Turbo's form submissions do, Hiccdown sends them as such, without a layout. Anything else is sent as HTML, as before.
- Hiccup's shorthand for ids and classes: `[:'div#main.big.red']` renders `<div id="main" class="big red">`, in any order after the tag name. An id in the attributes takes precedence, and their classes are added.
- Rails' tag helpers take Hiccdown as content, not just in blocks: `content_tag(:div, [:span, 'foo'])`, `tag.div([:span, 'foo'])`, `link_to([:span, 'foo'], path)`, and helpers of your own that yield into them.

### Fixes

- `render` with options only, like `render status: :not_found` or `render layout: 'admin'`, renders the action's helper method instead of looking for an ERB template.
- A block or `render hiccdown:` that returns an empty array no longer raises `NoMethodError`.
- An action's helper method is found by the controller's `action_name` rather than `params[:action]`, so controllers run without the router, as in `ProductsController.action(:show).call(env)`, no longer raise `NoMethodError`.
- On Rails 8.1, `capture` hands keyword arguments to its block as keywords, as Rails does.
- `content_tag(..., escape: false)` no longer escapes Hiccdown content.

### Development

- Hiccdown is developed against Rails 8.1 on Ruby 3.4.11 and tested against Rails 7.0, 7.1, 7.2, 8.0 and 8.1 (`rake test:rails`).
- `test/dummy` is a small Rails app for trying Hiccdown out in a browser, with system tests that drive it in headless Brave (`rake test:system`).
