module ItemsHelper
  def index
    items_page
  end

  # Turbo streams when the item is valid, the page again otherwise.
  def create
    if @name.empty?
      items_page([:p, {class: 'error'}, 'The name can’t be blank.'])
    else
      ts(:append, 'items', [:li, @name])
    end
  end

  # Not called `index` from `create`: every helper is in every view, so that
  # would be whichever helper's `index` came last.
  def items_page error = nil
    content_for(:title, 'Items')

    [:div,
      [:h1, 'Items'],
      error,
      [:ul, {id: 'items'}],
      items_form]
  end

  def items_form
    form_with(url: items_path) do |f|
      [:div,
        f.label(:name),
        f.text_field(:name),
        f.submit('Add')]
    end
  end
end
