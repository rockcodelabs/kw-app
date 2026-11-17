# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProfileMailer do
  describe '#apply' do
    let(:profile) { create(:profile) }
    let(:mail) { described_class.apply(profile) }

    it 'attaches the membership declaration as a PDF' do
      attachment = mail.attachments['zgloszenie_do_kw.pdf']

      expect(attachment).to be_present
      expect(attachment.body.raw_source).to start_with('%PDF')
    end

    it 'is addressed to the applicant with the club in copy' do
      expect(mail.to).to eq([profile.email])
      expect(mail.cc).to eq(['zgloszenia@kw.krakow.pl'])
    end
  end
end
