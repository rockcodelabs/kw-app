desc "This task is called by the Heroku scheduler add-on"

# Every scheduled task reports to healthchecks.io through Healthchecks::Monitored (ENV: HC_PING_KEY,
# HC_PING_PREFIX; set only on the production cron role). The tasks below the scheduled ones are dead
# code (A.2 in docs/NEW_PRODUCTION_PLAN.md) and report nothing.

task :send_prepaid_emails => :environment do
  Healthchecks::Monitored.call(:send_prepaid_emails) do
    Training::Supplementary::SendPrepaidEmail.new.send_prepaid_emails
  end
end

task :store_shmu => :environment do
  Scrappers::Shmu.new.call
end

task :store_topr => :environment do
  Scrappers::Topr.new.call
end

task :store_weather => :environment do
  Scrappers::Meteoblue.new.call
  Scrappers::WeatherStorage.new.call
end

task :send_reminders => :environment do
  Healthchecks::Monitored.call(:send_reminders) do
    Admin::ReservationReminder.send_reminders
  end
end

task :send_yearly_fee_reminder => :environment do
  Healthchecks::Monitored.call(:send_yearly_fee_reminder) do
    Membership::FeesReminderService.new.call
  end
end

task :destroy_unpaid_reservations => :environment do
  Healthchecks::Monitored.call(:destroy_unpaid_reservations) do
    ::Reservations::Workers::DestroyUnpaidReservationsWorker.perform_async
  end
end

task :destroy_outdated_profiles => :environment do
  Healthchecks::Monitored.call(:destroy_outdated_profiles) do
    ::Membership::Workers::DestroyOutdatedProfilesWorker.perform_async
  end
end

task :destroy_expired_events_sign_ups => :environment do
  expired_sign_ups = Events::Competitions::Repository.new.expired_sign_ups
  expired_sign_ups.each do |sign_up|
    Events::Competitions::Worker::DestroyExpiredSignUpWorker.perform_async(sign_up.id)
  end
end

task :destroy_expired_sign_ups => :environment do
  Healthchecks::Monitored.call(:destroy_expired_sign_ups) do
    expired_sign_ups = Training::Supplementary::Repository.new.expired_sign_ups
    expired_sign_ups.each do |sign_up|
      Training::Supplementary::Workers::DestroyExpiredSignUpWorker.perform_async(sign_up.id)
    end
    expired_business_sign_ups = ::Business::Repository.new.expired_sign_ups
    expired_business_sign_ups.each do |sign_up|
      ::Business::Workers::DestroyExpiredSignUpWorker.perform_async(sign_up.id)
    end
    sign_ups_for_equipment = ::Business::Repository.new.sign_ups_for_equipment
    sign_ups_for_equipment.each do |sign_up|
      ::Business::Workers::SendListWorker.perform_async(sign_up.id)
    end
  end
end

task :open_conversations => :environment do
  Healthchecks::Monitored.call(:open_conversations) do
    Training::Supplementary::Repository.new.fetch_active_courses.each_with_index do |course, index|
      Training::Supplementary::Workers::OpenConversationWorker.set(wait: index * 1.minute).perform_async(course.id)
    end
  end
end

task :fill_empty_places => :environment do
  Healthchecks::Monitored.call(:fill_empty_places) do
    Training::Supplementary::Repository.new.fetch_active_courses.each do |course|
      Training::Supplementary::FillEmptyPlaces.new(
        Training::Supplementary::Repository.new
      ).call(course_id: course.id)
    end
  end
end

task :set_regular_members => :environment do
  Healthchecks::Monitored.call(:set_regular_members) do
    UserManagement::Workers::SetRegularsWorker.perform_async
  end
end

task :recalculate_cost => :environment do
  Healthchecks::Monitored.call(:recalculate_cost) do
    UserManagement::RecalculateCost.new.all
  end
end
