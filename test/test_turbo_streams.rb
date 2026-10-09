require_relative 'test_helper'

module TurboStreamTest
  module ApplicationHelper
    def layout
      [:html, [:body, yield]]
    end
  end

  module AdminHelper
    def layout
      [:nav, yield]
    end
  end

  module ItemsHelper
    def stream
      [:'turbo-stream', {action: :update, target: 'item'},
        [:template, 'updated']]
    end

    def streams
      [[:'turbo-stream', {action: :remove, target: 'a'}],
        [:'turbo-stream', {action: :remove, target: 'b'}]]
    end

    # Streams from turbo-rails' own helper.
    def builder_stream
      [turbo_stream.remove('a'), turbo_stream.remove('b')]
    end

    def page
      [:p, 'page']
    end
  end

  module NamedHelper
    def stream
      [:'turbo-stream', {action: :remove, target: 'item'}]
    end
  end

  class ApplicationController < ActionController::Base
  end

  class ItemsController < ApplicationController
    def stream; end
    def streams; end
    def builder_stream; end
    def page; end
  end

  class NamedController < ApplicationController
    layout 'turbo_stream_test/admin'

    def stream; end
  end
end

class TurboStreamsTest < Minitest::Test
  include ControllerRequests

  # As Turbo sends with forms, which can be answered with streams or a page.
  STREAM = { 'HTTP_ACCEPT' => 'text/vnd.turbo-stream.html, text/html, application/xhtml+xml' }

  STREAM_TYPE = 'text/vnd.turbo-stream.html; charset=utf-8'
  HTML_TYPE = 'text/html; charset=utf-8'

  def test_stream
    assert_equal [STREAM_TYPE, '<turbo-stream action="update" target="item"><template>updated</template></turbo-stream>'],
      get(TurboStreamTest::ItemsController, :stream, STREAM)
  end

  def test_several_streams
    assert_equal [STREAM_TYPE, '<turbo-stream action="remove" target="a"></turbo-stream><turbo-stream action="remove" target="b"></turbo-stream>'],
      get(TurboStreamTest::ItemsController, :streams, STREAM)
  end

  def test_streams_from_turbo_stream_helper
    assert_equal [STREAM_TYPE, '<turbo-stream action="remove" target="a"></turbo-stream><turbo-stream action="remove" target="b"></turbo-stream>'],
      get(TurboStreamTest::ItemsController, :builder_stream, STREAM)
  end

  def test_stream_without_named_layout
    assert_equal [STREAM_TYPE, '<turbo-stream action="remove" target="item"></turbo-stream>'],
      get(TurboStreamTest::NamedController, :stream, STREAM)
  end

  # A page still answers a request that would take streams, in its layout.
  def test_page_for_stream_request
    assert_equal [HTML_TYPE, '<!DOCTYPE html><html><body><p>page</p></body></html>'],
      get(TurboStreamTest::ItemsController, :page, STREAM)
  end

  # Streams are only sent as such to requests that take them.
  def test_stream_for_html_request
    assert_equal [HTML_TYPE, '<!DOCTYPE html><html><body><turbo-stream action="update" target="item"><template>updated</template></turbo-stream></body></html>'],
      get(TurboStreamTest::ItemsController, :stream, {})
  end

  private

  def get controller, action, headers
    env = Rack::MockRequest.env_for('/', headers.merge('action_dispatch.request.path_parameters' => { action: action.to_s }))
    _status, response_headers, body = controller.action(action).call(env)
    html = +''
    body.each { |part| html << part }
    [response_headers['content-type'] || response_headers['Content-Type'], html]
  end
end
