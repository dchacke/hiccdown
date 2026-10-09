module RedirectsHelper
  def new
    content_for(:title, 'Redirect')

    [:div,
      [:h1, 'Redirect'],
      button_to('Submit and redirect', redirect_path)]
  end

  def show
    content_for(:title, 'Redirected')

    [:h1, 'Redirected']
  end
end
