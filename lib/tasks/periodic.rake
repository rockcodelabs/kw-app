desc "This task is called by the Heroku scheduler add-on"

# Every scheduled task reports to healthchecks.io through Healthchecks::Monitored (ENV: HC_PING_KEY,
# HC_PING_PREFIX; set only on the production cron role). The tasks below the scheduled ones are dead
# code (A.2 in docs/NEW_PRODUCTION_PLAN.md) and report nothing.
#
# DRY_RUN=1 bin/rake <task> (or bin/rake cron:dry_run for all of them) prints what a task would process
# (counts only) and does nothing else: `candidates:` is the read-only selection the real run uses.

task :send_prepaid_emails => :environment do
  Healthchecks::Monitored.call(:send_prepaid_emails,
                               candidates: -> { Training::Supplementary::SendPrepaidEmail.new.candidates.to_a.size }) do
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
  Healthchecks::Monitored.call(:send_reminders, candidates: -> { Admin::ReservationReminder.candidates.to_a.size }) do
    Admin::ReservationReminder.send_reminders
  end
end

task :send_yearly_fee_reminder => :environment do
  Healthchecks::Monitored.call(:send_yearly_fee_reminder,
                               candidates: -> { { recipients: Membership::FeesReminderService.new.recipient_emails.size } }) do
    Membership::FeesReminderService.new.call
  end
end

task :destroy_unpaid_reservations => :environment do
  Healthchecks::Monitored.call(:destroy_unpaid_reservations,
                               candidates: -> { ::Reservations::Workers::DestroyUnpaidReservationsWorker.candidates.size }) do
    ::Reservations::Workers::DestroyUnpaidReservationsWorker.perform_async
  end
end

task :destroy_outdated_profiles => :environment do
  Healthchecks::Monitored.call(:destroy_outdated_profiles,
                               candidates: -> { ::Membership::Workers::DestroyOutdatedProfilesWorker.candidates.to_a.size }) do
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
  Healthchecks::Monitored.call(
    :destroy_expired_sign_ups,
    candidates: lambda do
      {
        training: Training::Supplementary::Repository.new.expired_sign_ups.to_a.size,
        business: ::Business::Repository.new.expired_sign_ups.to_a.size,
        equipment_list: ::Business::Repository.new.sign_ups_for_equipment.to_a.size
      }
    end
  ) do
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
  Healthchecks::Monitored.call(:open_conversations,
                               candidates: -> { { courses: Training::Supplementary::Repository.new.fetch_active_courses.to_a.size } }) do
    Training::Supplementary::Repository.new.fetch_active_courses.each_with_index do |course, index|
      Training::Supplementary::Workers::OpenConversationWorker.set(wait: index * 1.minute).perform_async(course.id)
    end
  end
end

task :fill_empty_places => :environment do
  Healthchecks::Monitored.call(
    :fill_empty_places,
    candidates: lambda do
      repository = Training::Supplementary::Repository.new
      operation = Training::Supplementary::FillEmptyPlaces.new(repository)
      courses = repository.fetch_active_courses.to_a
      { courses: courses.size, sign_ups: courses.sum { |course| operation.candidates(course_id: course.id).size } }
    end
  ) do
    Training::Supplementary::Repository.new.fetch_active_courses.each do |course|
      Training::Supplementary::FillEmptyPlaces.new(
        Training::Supplementary::Repository.new
      ).call(course_id: course.id)
    end
  end
end

task :set_regular_members => :environment do
  Healthchecks::Monitored.call(:set_regular_members,
                               candidates: -> { UserManagement::Workers::SetRegularsWorker.candidates.count }) do
    UserManagement::Workers::SetRegularsWorker.perform_async
  end
end

task :recalculate_cost => :environment do
  Healthchecks::Monitored.call(:recalculate_cost,
                               candidates: -> { UserManagement::RecalculateCost.new.candidates.to_a.size }) do
    UserManagement::RecalculateCost.new.all
  end
end

namespace :cron do
  desc "Prints what every task of config/crontab would process (counts only); changes nothing"
  task :dry_run => :environment do
    names = File.readlines(Rails.root.join('config/crontab'), chomp: true)
                .reject { |line| line.strip.empty? || line.strip.start_with?('#') }
                .flat_map { |line| line.scan(%r{bin/rake (\w+)}).flatten }
                .uniq
    previous = ENV['DRY_RUN']
    ENV['DRY_RUN'] = '1'
    begin
      names.each do |name|
        Rake::Task[name].reenable
        Rake::Task[name].invoke
      end
    ensure
      previous.nil? ? ENV.delete('DRY_RUN') : ENV['DRY_RUN'] = previous
    end
  end
end
