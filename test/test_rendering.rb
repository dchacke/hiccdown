require_relative 'test_helper'

module RenderingTest
  module ProductsHelper
    def show
      [:p, 'product']
    end

    def admin
      [:p, 'admin']
    end
  end

  module AdminHelper
    def layout
      [:nav, yield]
    end
  end

  class ProductsController < ActionController::Base
    layout false

    # Options that say how to render the action, not what to render, still
    # render its helper method.
    def show
      render status: :not_found
    end

    def admin
      render layout: 'rendering_test/admin'
    end

    def plain
      render plain: 'plain', status: :accepted
    end
  end
end

class RenderingTest::Test < Minitest::Test
  include ControllerRequests

  def test_render_with_status_only
    assert_equal [404, '<p>product</p>'], request(RenderingTest::ProductsController, :show)
  end

  def test_render_with_layout_only
    assert_equal [200, '<nav><p>admin</p></nav>'], request(RenderingTest::ProductsController, :admin)
  end

  def test_render_with_content_option
    assert_equal [202, 'plain'], request(RenderingTest::ProductsController, :plain)
  end
end
