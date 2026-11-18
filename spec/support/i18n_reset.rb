# frozen_string_literal: true

# Controllers assign the global I18n.locale (ApplicationController#set_locale,
# ProfilesController) and never restore it, so a request spec can leak :en into
# later, unrelated specs depending on the random order. Reset it around every example.
RSpec.configure do |config|
  config.around(:each) do |example|
    I18n.with_locale(I18n.default_locale) { example.run }
  end
end
