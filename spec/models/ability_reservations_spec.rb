# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Ability for reservations' do
  let(:keeper) { create(:user, :with_reservations_role, :with_membership) }
  let(:member) { create(:user, :with_membership) }
  let(:admin) { create(:user, :admin, :with_membership) }
  let(:office) { create(:user, :with_office_role, :with_membership) }

  %i[manage give archive charge remind give_warning give_back_warning destroy create].each do |action|
    it "lets the reservations keeper #{action}" do
      expect(Ability.new(keeper).can?(action, Db::Reservation)).to be(true)
    end
  end

  %i[manage give archive charge remind give_warning give_back_warning destroy].each do |action|
    it "does not let a plain member #{action}" do
      expect(Ability.new(member).can?(action, Db::Reservation)).to be(false)
    end

    it "does not let the office role #{action} (separate permission)" do
      expect(Ability.new(office).can?(action, Db::Reservation)).to be(false)
    end
  end

  it 'does not grant reservation actions through the plain admin role (only the reservations role does)' do
    expect(Ability.new(admin).can?(:give, Db::Reservation)).to be(false)
    expect(Ability.new(admin).can?(:archive, Db::Reservation)).to be(false)
  end

  it 'gives an anonymous visitor no access' do
    expect(Ability.new(nil).can?(:give, Db::Reservation)).to be(false)
    expect(Ability.new(nil).can?(:archive, Db::Reservation)).to be(false)
  end
end
