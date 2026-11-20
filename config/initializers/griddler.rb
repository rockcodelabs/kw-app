Rails.application.config.to_prepare do
Griddler.configure do |config|
  config.email_service = :mailgun

  config.processor_class = ::EmailCenter::Mailman
  config.reply_delimiter = '-- ODPOWIEDZ E-MAILOWO POWYŻEJ TEJ LINI --'
  config.processor_method = :handle_it
end
end
