# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Events::Competitions::Workers::DestroyExpiredEventSignUpWorker do
  it 'destroys the sign-up through SignUps::Destroy' do
    destroy = instance_double(Events::Competitions::SignUps::Destroy)
    allow(Events::Competitions::SignUps::Destroy).to receive(:new).and_return(destroy)

    expect(destroy).to receive(:call).with(id: 42)

    described_class.new.perform(42)
  end
end
