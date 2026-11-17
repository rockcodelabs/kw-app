# frozen_string_literal: true

require 'rails_helper'

# Operations that call Success()/Failure() need `include Dry::Monads[:result]`.
# Without it they raise NoMethodError at the very end of the run (after side effects).
RSpec.describe 'dry-monads operations' do
  [
    Training::Questionare::SnwProfileService,
    Events::Competitions::SignUps::Destroy
  ].each do |klass|
    it "#{klass} provides Success() and Failure()" do
      instance = klass.allocate

      expect(instance.send(:Success, :ok)).to be_success
      expect(instance.send(:Failure, :nope)).to be_failure
    end
  end
end
