# frozen_string_literal: true

module Healthchecks
  # Runs a cron job and reports the outcome to healthchecks.io (see Healthchecks::Operation::Ping):
  # OK after the work finished, /fail with the error class when it raised (the error is re-raised so the
  # scheduler still logs it). The message is deliberately only the class name: error messages can hold
  # personal data. A ping problem never changes the outcome of the job.
  #
  # DRY_RUN=1 (or `dry_run: true`) only reports what the job would process: `candidates` is a lambda that
  # returns a count (or a hash of label => count). Nothing else happens: the work is not run, nothing is
  # enqueued or mailed, no ping is sent. Counts only, never ids or e-mail addresses (personal data).
  class Monitored
    DRY_RUN_VALUES = %w[1 true].freeze

    def self.call(job, ping: Operation::Ping.new, candidates: nil, dry_run: dry_run?, &work)
      return report_dry_run(job, candidates) if dry_run

      run(job, ping, &work)
    end

    def self.dry_run?
      DRY_RUN_VALUES.include?(ENV.fetch('DRY_RUN', '').strip.downcase)
    end

    def self.run(job, ping)
      result = yield
    rescue StandardError => e
      report(ping, job: job, status: :fail, message: e.class.name)
      raise
    else
      report(ping, job: job, status: :ok)
      result
    end
    private_class_method :run

    def self.report_dry_run(job, candidates)
      raise ArgumentError, "#{job} has no candidates selector, refusing to run it in DRY_RUN mode" unless candidates

      counts = candidates.call
      pairs = counts.is_a?(Hash) ? counts : { count: counts }
      $stdout.puts("DRY_RUN #{job}: #{pairs.map { |label, count| "#{label}=#{count}" }.join(' ')}")
      counts
    end
    private_class_method :report_dry_run

    def self.report(ping, **args)
      ping.call(**args)
    rescue StandardError => e
      Rails.logger.warn("[healthchecks] ping crashed: #{e.class}")
    end
    private_class_method :report
  end
end
