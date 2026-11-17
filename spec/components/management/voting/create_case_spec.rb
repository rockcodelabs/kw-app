# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Management::Voting::CreateCase do
  subject(:service) { described_class.new(Management::Voting::CaseForm) }

  let(:creator) { create(:user, :with_membership, :with_profile) }
  let!(:manager) { create(:user, :with_membership, :with_profile, roles: ['management']) }
  let(:inputs) { { name: 'Uchwała', creator_id: creator.id.to_s, voting_type: 'document' } }

  before { ActiveJob::Base.queue_adapter = :test }

  def call(overrides = {})
    service.call(raw_inputs: ActionController::Parameters.new(inputs.merge(overrides)))
  end

  it 'creates the case' do
    expect { expect(call).to eq(Dry::Monads::Success(:success)) }.to change(Management::Voting::CaseRecord, :count).by(1)

    expect(Management::Voting::CaseRecord.last).to have_attributes(name: 'Uchwała', creator_id: creator.id)
  end

  it 'notifies and mails the management users' do
    expect { call }
      .to change(NotificationCenter::NotificationRecord, :count).by(1)
      .and have_enqueued_mail(Management::Voting::Mailer, :notify)

    expect(NotificationCenter::NotificationRecord.last).to have_attributes(recipient_id: manager.id, action: 'created_voting')
  end

  it 'finishes the case immediately and notifies nobody when votes are hidden' do
    expect { call(hide_votes: '1') }.not_to change(NotificationCenter::NotificationRecord, :count)

    expect(Management::Voting::CaseRecord.last.state).to eq('finished')
  end

  it 'returns Polish errors and creates nothing when the name is blank' do
    result = nil

    expect { result = call(name: '') }.not_to change(Management::Voting::CaseRecord, :count)

    expect(result.failure[:name]).to eq(['musi być wypełnione'])
  end
end
