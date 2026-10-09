require_relative 'test_helper'

# The controllers are namespaced so their helpers, and the layouts named after
# them, don't clash with anything else. Rails looks for each controller's
# layout under `layouts/layout_test/`, as `LayoutTest::<Name>Helper#layout`.
module LayoutTest
  module ApplicationHelper
    def layout
      [:html,
        [:head, [:title, yield(:title)]],
        [:body, yield]]
    end
  end

  module PagesHelper
    def show
      content_for(:title, 'Page')
      [:p, 'page']
    end
  end

  # Overrides the application's helper layout.
  module ProductsHelper
    def show
      [:p, 'products']
    end

    def layout
      [:main, yield]
    end
  end

  # Has a layout file and no helper layout.
  module WidgetsHelper
    def show
      [:p, 'widgets']
    end
  end

  # Has both a layout file and a helper layout.
  module GadgetsHelper
    def show
      [:p, 'gadgets']
    end

    def layout
      [:div, yield]
    end
  end

  # A named layout.
  module AdminHelper
    def layout
      [:nav, yield]
    end
  end

  module LegacyHelper
    def show
      [:p, 'legacy']
    end
  end

  module NamedHelper
    def show
      [:p, 'named']
    end

    def explicit
      [:p, 'explicit']
    end
  end

  class ApplicationController < ActionController::Base
    self.view_paths = [File.expand_path('views', __dir__)]
  end

  class PagesController < ApplicationController
    def show; end
    def erb; end
  end

  class ProductsController < ApplicationController
    def show; end
  end

  class WidgetsController < ApplicationController
    def show; end
  end

  class GadgetsController < ApplicationController
    def show; end
  end

  class NamedController < ApplicationController
    layout 'layout_test/admin'

    def show; end

    def explicit
      render :explicit, layout: 'layout_test/admin'
    end
  end

  class LegacyController < ApplicationController
    layout 'layout_test/legacy'

    def show; end
  end
end

class LayoutsTest < Minitest::Test
  include ControllerRequests

  def setup
    @log = StringIO.new
    @logger = ActionController::Base.logger
    ActionController::Base.logger = Logger.new(@log)
  end

  def teardown
    ActionController::Base.logger = @logger
  end

  def test_application_helper_layout
    assert_equal '<!DOCTYPE html><html><head><title>Page</title></head><body><p>page</p></body></html>',
      get(LayoutTest::PagesController)
  end

  def test_application_helper_layout_around_erb_view
    assert_equal '<!DOCTYPE html><html><head><title></title></head><body><p>erb</p></body></html>',
      get(LayoutTest::PagesController, :erb)
  end

  def test_controller_helper_layout_overrides_application_layout
    assert_equal '<main><p>products</p></main>', get(LayoutTest::ProductsController)
  end

  def test_controller_layout_file_overrides_application_helper_layout
    assert_equal '<section><p>widgets</p></section>', get(LayoutTest::WidgetsController)
  end

  def test_helper_layout_takes_precedence_over_layout_file
    assert_equal '<div><p>gadgets</p></div>', get(LayoutTest::GadgetsController)
    assert_includes @log.string, 'LayoutTest::GadgetsHelper#layout takes precedence over the layout file layouts/layout_test/gadgets'
  end

  def test_no_warning_without_layout_file
    get(LayoutTest::ProductsController)
    refute_includes @log.string, 'Hiccdown'
  end

  def test_named_helper_layout
    assert_equal '<nav><p>named</p></nav>', get(LayoutTest::NamedController)
  end

  def test_named_layout_file
    assert_equal '<aside><p>legacy</p></aside>', get(LayoutTest::LegacyController)
  end

  def test_explicit_helper_layout
    assert_equal '<nav><p>explicit</p></nav>', get(LayoutTest::NamedController, :explicit)
  end

  private

  def get controller, action = :show
    request(controller, action).last
  end
end
