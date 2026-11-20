# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Settlement::ContractMailer, type: :mailer do
  let(:creator) { create(:user, :with_membership, :with_profile) }
  let(:colleague) { create(:user, :with_membership, :with_profile) }
  let(:contractor) { Settlement::ContractorRecord.create!(name: 'ACME') }
  let(:contract) do
    Settlement::ContractRecord.create!(
      title: 'Wynajem sali', creator_id: creator.id, contractor_id: contractor.id,
      document_number: 'FV/1', document_date: Date.current, cost: 100.0, currency_type: :pln,
      document_type: :bill, payout_type: :to_contractor,
      period_date: Date.new(2030, 1, 1), internal_number: 7, user_ids: [colleague.id]
    )
  end

  describe '#state_changed' do
    subject(:mail) { described_class.state_changed(contract) }

    it 'goes to the creator and the contract users, once each' do
      expect(mail.to).to contain_exactly(creator.email, colleague.email)
      expect(mail.from).to eq(['rozliczenia@kw.krakow.pl'])
    end

    it 'names the contract, its number and the new state in the subject' do
      contract.update_column(:state, 'accepted')

      expect(mail.subject).to include('Wynajem sali', '#7/2030', I18n.t('accepted', scope: 'activerecord.attributes.settlement/contract_record.states'))
    end

    it 'renders the body for every state of the workflow' do
      %w[new accepted preclosed closed].each do |state|
        contract.update_column(:state, state)

        expect { described_class.state_changed(contract.reload).body.encoded }.not_to raise_error
      end
    end

    it 'does not send the creator a duplicate when they are also a contract user' do
      contract.update!(user_ids: [creator.id])

      expect(mail.to).to eq([creator.email])
    end
  end

  describe '#notify' do
    subject(:mail) { described_class.notify(contract) }

    it 'announces a new contract to the creator and the contract users' do
      expect(mail.to).to contain_exactly(creator.email, colleague.email)
      expect(mail.subject).to start_with('Nowe rozliczenie: Wynajem sali #7/2030')
    end

    it 'renders the body' do
      expect { mail.body.encoded }.not_to raise_error
    end
  end
end
