# frozen_string_literal: true

module Healthchecks
  # Runs a cron job and reports the outcome to healthchecks.io (see Healthchecks::Operation::Ping):
  # OK after the work finished, /fail with the error class when it raised (the error is re-raised so the
  # scheduler still logs it). The message is deliberately only the class name: error messages can hold
  # personal data. A ping problem never changes the outcome of the job.
  class Monitored
    def self.call(job, ping: Operation::Ping.new)
      result = yield
    rescue StandardError => e
      report(ping, job: job, status: :fail, message: e.class.name)
      raise
    else
      report(ping, job: job, status: :ok)
      result
    end

    def self.report(ping, **args)
      ping.call(**args)
    rescue StandardError => e
      Rails.logger.warn("[healthchecks] ping crashed: #{e.class}")
    end
    private_class_method :report
  end
end
