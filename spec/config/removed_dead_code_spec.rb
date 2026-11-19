# frozen_string_literal: true

require 'rails_helper'

# Club decisions of 2026-11-19 (A.2 / A.4 in docs/NEW_PRODUCTION_PLAN.md): the voting reminder was never
# scheduled and is deleted, and the pdf-reader gem has no caller left.
RSpec.describe 'removed dead code' do # rubocop:disable RSpec/DescribeClass
  it 'has no Management::Voting::Reminder (the voting feature itself and its mailer stay)' do
    expect(Management::Voting.const_defined?(:Reminder, false)).to be(false)
    expect(Management::Voting::Mailer).to respond_to(:notify)
  end

  it 'no longer depends on pdf-reader' do
    expect(Rails.root.join('Gemfile').read).not_to match(/pdf-reader/)
    expect(Rails.root.join('Gemfile.lock').read).not_to match(/pdf-reader/)
    expect(defined?(PDF::Reader)).to be_nil
  end

  it 'still has prawn and its ttfunk dependency (used for the PDF documents the app generates)' do
    expect(Rails.root.join('Gemfile.lock').read).to match(/^    ttfunk /)
  end
end
