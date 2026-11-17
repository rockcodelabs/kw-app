# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Management::Voting::CreateCommission do
  subject(:service) { described_class.new(Management::Voting::CommissionForm) }

  let(:owner) { create(:user, :with_membership, :with_profile) }
  let(:authorized) { create(:user, :with_membership, :with_profile) }
  let(:inputs) { ActionController::Parameters.new(owner_id: owner.id, authorized_id: authorized.id, approval: true).permit! }

  before { ActiveJob::Base.queue_adapter = :test }

  it 'creates the commission and mails the authorized user' do
    result = nil

    expect { result = service.call(raw_inputs: inputs) }
      .to change(Management::Voting::CommissionRecord, :count).by(1)
      .and have_enqueued_mail(Management::Voting::Mailer, :notify_commission)

    expect(result).to be_success
    expect(result.value!).to have_attributes(owner_id: owner.id, authorized_id: authorized.id)
  end

  it 'returns the model errors when saving fails' do
    commission = instance_double(Management::Voting::CommissionRecord, save: false, errors: double(full_messages: ['Błąd']))
    allow(Management::Voting::CommissionRecord).to receive(:new).and_return(commission)

    expect(service.call(raw_inputs: inputs)).to eq(Dry::Monads::Failure(['Błąd']))
  end
end
