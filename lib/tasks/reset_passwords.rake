# Mails a password-reset link to EVERY user, so it refuses to run without CONFIRM=yes.
task :reset_passwords => :environment do
  unless ENV['CONFIRM'] == 'yes'
    abort "reset_passwords would mail a reset link to #{Db::User.count} users. Run again with CONFIRM=yes to do it."
  end

  Db::User.find_each do |user|
    user.send_reset_password_instructions
  end
end
