# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Events::Competitions::Workers::DestroyExpiredEventSignUpWorker do
  it 'destroys the sign-up through SignUps::Destroy' do
    destroy = instance_double(Events::Competitions::SignUps::Destroy)
    allow(Events::Competitions::SignUps::Destroy).to receive(:new).and_return(destroy)

    expect(destroy).to receive(:call).with(id: 42)

    described_class.new.perform(42)
  end

  # G41: the cron destroys sign-ups nobody is watching, so the destroy has to leave a trail that answers
  # "who removed this, when, and what was in it" later (PaperTrail, as for Business::SignUpRecord).
  describe 'audit trail' do
    let(:competition) do
      Events::Db::CompetitionRecord.create!(
        name: 'Zawody', edition_sym: 'zawody', email_text: 'x', rules_text: 'x', medical_rules_text: 'x', rules: 'x',
        sign_up_starts_at: 1.day.ago, event_date: 1.month.from_now
      )
    end
    let(:package) { competition.package_types.create!(name: 'Poza KW', cost: 60) }
    let!(:sign_up) do
      Events::Db::SignUpRecord.create!(
        competition_record_id: competition.id, competition_package_type_1_id: package.id, participant_name_1: 'Jan Kowalski',
        participant_email_1: 'jan@example.com', sent_at: 3.days.ago, expired_at: 1.day.ago
      )
    end
    let!(:payment) { create(:payment, payable: sign_up) }
    let(:label) { 'cron:destroy_expired_events_sign_ups' }

    def destroy_version(item_type, item_id)
      PaperTrail::Version.find_by(item_type: item_type, item_id: item_id, event: 'destroy')
    end

    it 'destroys the sign-up and its payment' do
      expect { described_class.new.perform(sign_up.id) }
        .to change(Events::Db::SignUpRecord, :count).by(-1).and change(Db::Payment, :count).by(-1)
    end

    it 'records who destroyed the sign-up' do
      described_class.new.perform(sign_up.id)

      expect(destroy_version('Events::Db::SignUpRecord', sign_up.id)).to have_attributes(whodunnit: label)
    end

    it 'records who destroyed the payment' do
      described_class.new.perform(sign_up.id)

      expect(destroy_version('Db::Payment', payment.id)).to have_attributes(whodunnit: label)
    end

    # Read the stored row as text: `version.reify` cannot load timestamps under the Rails 7 safe-YAML defaults
    # (an app-wide limitation, true for every versioned model), but the data itself is kept.
    it 'keeps what was in the sign-up, so it can be looked up later' do
      described_class.new.perform(sign_up.id)

      expect(destroy_version('Events::Db::SignUpRecord', sign_up.id).object)
        .to include('participant_name_1: Jan Kowalski', 'participant_email_1: jan@example.com', "id: #{sign_up.id}")
    end

    it 'does not leave the cron label behind for later changes in the same process' do
      described_class.new.perform(sign_up.id)

      expect(PaperTrail.request.whodunnit).to be_nil
    end
  end
end
