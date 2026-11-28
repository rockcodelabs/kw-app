# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Library::Operation::BackfillEditionInfo do
  subject(:operation) { described_class.new }

  let!(:with_autors) { create(:library_item, item_id: 10, autors: 'Warszawa 1998') }
  let!(:with_both) { create(:library_item, item_id: 11, autors: 'Kraków 2001', edition_info: 'Wyd. II, Kraków 2005') }
  let!(:without_autors) { create(:library_item, item_id: 12, autors: nil) }
  let!(:blank_autors) { create(:library_item, item_id: 13, autors: '   ') }
  let!(:padded) { create(:library_item, item_id: 14, autors: '  Gdańsk 1987  ') }

  describe 'dry run (default)' do
    it 'returns Success with counts' do
      result = operation.call

      expect(result).to be_success
      expect(result.success).to include(total: 5, with_autors: 3, already_filled: 1, candidates: 2,
                                        applied: false, updated: 0)
    end

    it 'does not write anything' do
      expect { operation.call }.not_to(change { Library::ItemRecord.order(:id).pluck(:edition_info) })
    end

    it 'returns a sample of the rows it would fill, with trimmed text' do
      sample = operation.call.success[:sample]

      expect(sample).to contain_exactly(
        { id: with_autors.id, number: 10, edition_info: 'Warszawa 1998' },
        { id: padded.id, number: 14, edition_info: 'Gdańsk 1987' }
      )
    end
  end

  describe 'apply: true' do
    it 'copies autors into edition_info for blank edition_info only' do
      operation.call(apply: true)

      expect(with_autors.reload.edition_info).to eq('Warszawa 1998')
      expect(padded.reload.edition_info).to eq('Gdańsk 1987')
    end

    it 'reports how many rows it updated' do
      expect(operation.call(apply: true).success).to include(applied: true, updated: 2, candidates: 2)
    end

    it 'never overwrites an existing edition_info' do
      operation.call(apply: true)

      expect(with_both.reload.edition_info).to eq('Wyd. II, Kraków 2005')
    end

    it 'leaves items without a usable autors alone' do
      operation.call(apply: true)

      expect(without_autors.reload.edition_info).to be_nil
      expect(blank_autors.reload.edition_info).to be_nil
    end

    it 'never changes autors' do
      expect { operation.call(apply: true) }.not_to(change { Library::ItemRecord.order(:id).pluck(:autors) })
    end

    it 'does not touch updated_at' do
      expect { operation.call(apply: true) }.not_to(change { with_autors.reload.updated_at })
    end

    it 'is idempotent: a second run has nothing left to do' do
      operation.call(apply: true)

      result = operation.call(apply: true)

      expect(result.success).to include(candidates: 0, updated: 0)
    end

    it 'works on rows that would fail the current model validations' do
      invalid = create(:library_item, item_id: 15, autors: 'Zakopane 1990')
      invalid.update_columns(title: nil)

      operation.call(apply: true)

      expect(invalid.reload.edition_info).to eq('Zakopane 1990')
    end
  end

  describe 'failure handling' do
    it 'rolls back everything and returns Failure when the updated row count is unexpected' do
      allow_any_instance_of(ActiveRecord::Relation).to receive(:update_all).and_wrap_original do |original, *args|
        original.call(*args)
        99
      end

      result = operation.call(apply: true)

      expect(result).to be_failure
      expect(result.failure[:error]).to eq('ActiveRecord::RecordNotSaved')
      expect(with_autors.reload.edition_info).to be_nil
      expect(padded.reload.edition_info).to be_nil
    end

    it 'returns Failure when the database raises' do
      allow(Library::ItemRecord).to receive(:count).and_raise(ActiveRecord::StatementInvalid, 'boom')

      expect(operation.call).to be_failure
    end
  end
end
