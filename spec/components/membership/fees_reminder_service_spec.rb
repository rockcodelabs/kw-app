# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Membership::FeesReminderService do
  before do
    ActiveJob::Base.queue_adapter = :test
    allow_any_instance_of(Membership::FeesRepository)
      .to receive(:get_unpaid_kw_ids_this_year).and_return([9001, 9002, 9003, 9004])
  end

  def member(kw_id:, email:, position: [])
    record = create(:profile, email: email, position: position)
    record.update_column(:kw_id, kw_id)
    record
  end

  let!(:regular)   { member(kw_id: 9001, email: 'regular@example.com') }
  let!(:honorable) { member(kw_id: 9002, email: 'honorable@example.com', position: ['honorable_kw']) }
  let!(:senior)    { member(kw_id: 9003, email: 'senior@example.com', position: ['senior']) }
  let!(:paid_up)   { member(kw_id: 9999, email: 'paid@example.com') }

  describe '#recipient_emails' do
    it 'lists members with an unpaid fee, without honorary and senior members' do
      expect(described_class.new.recipient_emails).to contain_exactly('regular@example.com')
    end
  end

  describe '#call' do
    it 'mails exactly those recipients' do
      expect { described_class.new.call }
        .to have_enqueued_mail(Membership::FeesMailer, :yearly_reminder).with(['regular@example.com'])
    end
  end
end
