module ApplicationHelper
  include Hiccdown::ViewHelpers

  def layout
    [:html,
      [:head,
        [:title, yield(:title)],
        csrf_meta_tags,
        javascript_importmap_tags],
      [:body,
        [:nav, link_to('Hiccdown', root_path)],
        [:main, yield]]]
  end

  def ts action, target, *children
    [:'turbo-stream', {action: action, target: target},
      [:template, *children]]
  end
end
