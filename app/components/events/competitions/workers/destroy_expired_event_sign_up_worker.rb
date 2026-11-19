module Events
  module Competitions
    module Workers
      class DestroyExpiredEventSignUpWorker
        include Sidekiq::Worker

        # There is no signed-in user in a cron job; the label tells the history who removed the sign-up (G41).
        WHODUNNIT = 'cron:destroy_expired_events_sign_ups'

        def perform(sign_up_id)
          PaperTrail.request(whodunnit: WHODUNNIT) do
            ::Events::Competitions::SignUps::Destroy.new(
              Events::Competitions::Repository.new
            ).call(id: sign_up_id)
          end
        end
      end
    end
  end
end

