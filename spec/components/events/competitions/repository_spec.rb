# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Events::Competitions::Repository do
  # Rails 6.1 changed `where.not(a: nil, b: nil)` to `NOT (a IS NULL AND b IS NULL)`;
  # the cron task destroys what this returns, so both columns must be required.
  describe '#expired_sign_ups' do
    it 'requires sent_at and expired_at to be present' do
      sql = described_class.new.expired_sign_ups.to_sql

      expect(sql).to include('"sent_at" IS NOT NULL')
      expect(sql).to include('"expired_at" IS NOT NULL')
      expect(sql).not_to include('NOT ("events_sign_ups"."sent_at" IS NULL')
    end
  end
end
