module PagesHelper
  def index
    content_for(:title, 'Hiccdown')

    [:div,
      [:h1, 'Hiccdown'],
      [:ul,
        [:li, link_to('An ERB view in a helper layout', erb_path)],
        [:li, link_to('A Turbo frame', frame_path)],
        [:li, link_to('A form answered with turbo streams', items_path)],
        [:li, link_to('A form that redirects', redirect_path)]]]
  end
end
