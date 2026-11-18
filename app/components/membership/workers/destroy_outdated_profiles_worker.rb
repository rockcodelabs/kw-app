require 'net/http'

module Membership
  module Workers
    class DestroyOutdatedProfilesWorker
      include Sidekiq::Worker

      def self.candidates
        ::Membership::FeesRepository.new.find_outdated_not_prepaided_profiles
      end

      def perform(**)
        self.class.candidates.map(&:destroy)
      end
    end
  end
end
