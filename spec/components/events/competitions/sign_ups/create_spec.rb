# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Events::Competitions::SignUps::Create do
  subject(:service) { described_class.new(Events::Competitions::Repository.new, competition.form) }

  let(:accept_first) { false }
  let(:close_payment) { nil }
  let!(:competition) do
    Events::Db::CompetitionRecord.create!(
      name: 'Zawody', edition_sym: 'z', email_text: 'x', event_date: 1.month.from_now,
      accept_first: accept_first, close_payment: close_payment
    )
  end
  let!(:package) { competition.package_types.create!(name: 'Poza KW', cost: 60) }
  let(:inputs) do
    ActionController::Parameters.new(
      participant_name_1: 'Jan Kowalski', participant_gender_1: 'male', participant_email_1: 'jan@example.com',
      participant_birth_year_1: '1990', competition_package_type_1_id: package.id.to_s, terms_of_service: '1'
    ).permit!
  end

  before { ActiveJob::Base.queue_adapter = :test }

  def call(overrides = {})
    service.call(competition_id: competition.id, raw_inputs: ActionController::Parameters.new(inputs.to_h.merge(overrides)).permit!)
  end

  it 'creates the sign up with a payment and mails the participant' do
    expect { expect(call).to eq(Dry::Monads::Success(:success)) }
      .to change(Events::Db::SignUpRecord, :count).by(1)
      .and have_enqueued_mail(Events::Competitions::SignUpMailer, :sign_up)

    sign_up = Events::Db::SignUpRecord.last
    expect(sign_up).to have_attributes(participant_name_1: 'Jan Kowalski', competition_record_id: competition.id)
    expect(sign_up.sent_at).to be_present
    expect(sign_up.payment).to be_present
  end

  context 'when the competition accepts sign ups manually' do
    let(:accept_first) { true }

    it 'mails the accept-first message and does not mark the sign up as sent' do
      expect { call }.to have_enqueued_mail(Events::Competitions::SignUpMailer, :sign_up_accept_first)

      expect(Events::Db::SignUpRecord.last.sent_at).to be_nil
    end
  end

  context 'when the payment deadline is set' do
    let(:close_payment) { 3.days.from_now.change(usec: 0) }

    it 'copies it to the sign up' do
      call

      expect(Events::Db::SignUpRecord.last.expired_at).to eq(close_payment)
    end
  end

  it 'returns Polish errors and creates nothing when invalid' do
    result = nil

    expect { result = call(participant_name_1: '') }.not_to change(Events::Db::SignUpRecord, :count)

    expect(result).to be_failure
    expect(result.failure[:participant_name_1]).to eq(['Imię i nazwisko 1 nie może być puste'])
  end

  it 'uses the current locale for the messages' do
    result = I18n.with_locale(:en) { call(participant_email_1: 'nope') }

    expect(result.failure[:participant_email_1]).to eq(['E-mail 1 is invalid'])
  end
end
