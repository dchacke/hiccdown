require_relative 'application_system_test_case'

class DummyTest < ApplicationSystemTestCase
  def test_helper_layout_with_title
    visit root_path
    assert_title 'Hiccdown'
    assert_selector 'h1', text: 'Hiccdown'
  end

  def test_erb_view_in_helper_layout
    visit erb_path
    assert_title 'ERB'
    assert_selector 'nav a', text: 'Hiccdown'
    assert_text 'This view is ERB, in a helper layout.'
  end

  # Turbo replaces only the frame, without leaving the page.
  def test_turbo_frame
    visit frame_path
    click_link 'Load into the frame'
    assert_selector 'turbo-frame#frame p', text: 'Loaded into the frame.'
    assert_title 'Frame'
    assert_current_path frame_path
  end

  def test_form_answered_with_turbo_stream
    visit items_path
    fill_in 'Name', with: 'First'
    click_button 'Add'
    assert_selector '#items li', text: 'First'
    assert_current_path items_path
  end

  def test_form_answered_with_page
    visit items_path
    click_button 'Add'
    assert_text 'The name can’t be blank.'
    assert_title 'Items'
  end

  def test_redirect_takes_one_request
    visit redirect_path
    RedirectsController.requests.clear
    click_button 'Submit and redirect'
    assert_selector 'h1', text: 'Redirected'
    assert_equal [['POST', '/redirect'], ['GET', '/redirected']], RedirectsController.requests.map { |method, path, _format| [method, path] }
  end
end
