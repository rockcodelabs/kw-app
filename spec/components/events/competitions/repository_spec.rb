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

    # G41 (owner decision 2026-11-19): the 89 old sign-ups (2022 - May 2026) of the restored data are purged by the
    # first scheduled run on purpose. The destroy is versioned (see the worker spec), so there is no age limit here.
    context 'with rows' do
      let(:competition) do
        Events::Db::CompetitionRecord.create!(
          name: 'Zawody', edition_sym: 'zawody', email_text: 'x', rules_text: 'x', medical_rules_text: 'x', rules: 'x',
          sign_up_starts_at: 1.day.ago, event_date: 1.month.from_now
        )
      end
      let!(:package) { competition.package_types.create!(name: 'Poza KW', cost: 60) }

      def sign_up_with_payment(state: 'unpaid', sent_at: 10.days.ago, expired_at:)
        sign_up = Events::Db::SignUpRecord.create!(
          competition_record_id: competition.id, competition_package_type_1_id: package.id, participant_name_1: 'Jan Kowalski',
          sent_at: sent_at, expired_at: expired_at
        )
        create(:payment, state: state, payable: sign_up)
        sign_up
      end

      it 'returns an unpaid sign-up that expired a moment ago' do
        expired = sign_up_with_payment(expired_at: 1.hour.ago)

        expect(described_class.new.expired_sign_ups).to contain_exactly(expired)
      end

      it 'also returns the old backlog, however long ago it expired' do
        recent = sign_up_with_payment(expired_at: 1.hour.ago)
        old = sign_up_with_payment(expired_at: Time.zone.local(2022, 3, 4, 18))

        expect(described_class.new.expired_sign_ups).to contain_exactly(recent, old)
      end

      it 'leaves a sign-up that has not expired yet alone' do
        sign_up_with_payment(expired_at: 1.hour.from_now)

        expect(described_class.new.expired_sign_ups).to be_empty
      end

      it 'leaves a paid sign-up alone even when it expired recently' do
        sign_up_with_payment(state: 'prepaid', expired_at: 1.hour.ago)

        expect(described_class.new.expired_sign_ups).to be_empty
      end

      it 'leaves a sign-up that was never sent a payment link alone' do
        sign_up_with_payment(sent_at: nil, expired_at: 1.hour.ago)

        expect(described_class.new.expired_sign_ups).to be_empty
      end
    end
  end
end
