require_relative 'test_helper'

# A mailer's helper is named after it, as a controller's is, so the HTML part
# of `WelcomeMailer#hello` is `WelcomeMailerHelper#hello`. Its templates are
# in `views/mailer_test/welcome_mailer/`.
module MailerTest
  module WelcomeMailerHelper
    def hello
      [:p, "Hello, ", @name]
    end

    def footer
      content_for(:footer, 'Unsubscribe')
      [:p, 'With a footer']
    end

    # Has a text template too.
    def both
      [:p, 'Hello in HTML']
    end

    def block
      [:p, 'From a block']
    end

    # Has an HTML template too.
    def override
      [:p, 'From the helper']
    end
  end

  # The layout `mailer_test/mail`, for HTML. Text has a layout file.
  module MailHelper
    def layout
      [:html,
        [:body, yield, [:footer, yield(:footer)]]]
    end
  end

  class WelcomeMailer < ActionMailer::Base
    prepend_view_path File.expand_path('views', __dir__)
    default from: 'from@example.com', to: 'to@example.com'

    def hello
      @name = '<Ada>'
      mail
    end

    def footer
      mail
    end

    def both
      mail
    end

    def block
      mail { |format| format.html; format.text { render plain: 'From a block in text' } }
    end

    def override
      mail
    end

    def erb
      mail
    end

    def missing
      mail
    end
  end

  class LayoutMailer < WelcomeMailer
    layout 'mailer_test/mail'

    def footer
      mail(template_path: 'mailer_test/welcome_mailer')
    end

    def both
      mail(template_path: 'mailer_test/welcome_mailer')
    end
  end
end

class MailersTest < Minitest::Test
  def html mail
    (mail.html_part || mail).body.decoded
  end

  def test_html_from_the_helper_method
    mail = MailerTest::WelcomeMailer.hello

    assert_equal 'text/html; charset=UTF-8', mail.content_type
    assert_equal '<p>Hello, &lt;Ada&gt;</p>', html(mail)
  end

  def test_text_template_beside_the_helper_method
    mail = MailerTest::WelcomeMailer.both

    assert mail.multipart?
    assert_equal '<p>Hello in HTML</p>', html(mail)
    assert_equal "Hello in text\n", mail.text_part.body.decoded
  end

  def test_formats_in_a_block
    mail = MailerTest::WelcomeMailer.block

    assert_equal '<p>From a block</p>', html(mail)
    assert_equal 'From a block in text', mail.text_part.body.decoded
  end

  def test_helper_method_over_template
    assert_equal '<p>From the helper</p>', html(MailerTest::WelcomeMailer.override)
  end

  def test_template_without_helper_method
    assert_equal "<p>From ERB</p>\n", html(MailerTest::WelcomeMailer.erb)
  end

  def test_missing_helper_method_and_template
    assert_raises(ActionView::MissingTemplate) { MailerTest::WelcomeMailer.missing.body }
  end

  def test_helper_layout
    mail = MailerTest::LayoutMailer.footer

    assert_equal '<!DOCTYPE html><html><body><p>With a footer</p><footer>Unsubscribe</footer></body></html>', html(mail)
  end

  def test_text_layout_file_beside_helper_layout
    mail = MailerTest::LayoutMailer.both

    assert_equal '<!DOCTYPE html><html><body><p>Hello in HTML</p><footer></footer></body></html>', html(mail)
    assert_equal "Hello in text\n\n-- The text layout\n", mail.text_part.body.decoded
  end
end
