module Hiccdown
  class Railtie < Rails::Railtie
    initializer 'hiccdown.configure_template_handler' do
      ActionView::Template.register_template_handler :hdml, Hiccdown::HdmlHandler
      ActionView::Base.default_formats << :hdml
    end
  end

  class HdmlHandler
    def self.call(template, source)
      <<-RUBY
        Hiccdown::to_html(#{source}).html_safe
      RUBY
    end
  end
end
