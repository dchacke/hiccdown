module FramesHelper
  def show
    content_for(:title, 'Frame')

    [:div,
      [:h1, 'Frame'],
      [:'turbo-frame', {id: 'frame'},
        link_to('Load into the frame', frame_content_path)]]
  end

  def content
    content_for(:title, 'Frame content')

    [:'turbo-frame', {id: 'frame'},
      [:p, 'Loaded into the frame.']]
  end
end
