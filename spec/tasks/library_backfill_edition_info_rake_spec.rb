# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'library:backfill_edition_info rake task' do
  let(:task) { Rake::Task['library:backfill_edition_info'] }

  before do
    Rails.application.load_tasks unless Rake::Task.task_defined?('library:backfill_edition_info')
    task.reenable
    create(:library_item, item_id: 10, autors: 'Warszawa 1998')
  end

  after { ENV.delete('APPLY') }

  it 'is a dry run by default and prints the counts' do
    expect { task.invoke }.to output(/To fill \(candidates\):\s+1.*DRY RUN: nothing was written/m).to_stdout
    expect(Library::ItemRecord.first.edition_info).to be_nil
  end

  it 'writes only with APPLY=1' do
    ENV['APPLY'] = '1'

    expect { task.invoke }.to output(/APPLIED: 1 rows updated/).to_stdout
    expect(Library::ItemRecord.first.edition_info).to eq('Warszawa 1998')
  end

  it 'does not write for any other APPLY value' do
    ENV['APPLY'] = 'true'

    expect { task.invoke }.to output(/DRY RUN/).to_stdout
    expect(Library::ItemRecord.first.edition_info).to be_nil
  end

  it 'aborts with a message when the operation fails' do
    allow_any_instance_of(Library::Operation::BackfillEditionInfo)
      .to receive(:call).and_return(Dry::Monads::Failure(error: 'X'))

    expect { task.invoke }.to raise_error(SystemExit).and output(/FAILED, nothing was changed/).to_stderr
  end
end
