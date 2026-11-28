# frozen_string_literal: true

namespace :library do
  desc 'Copy library_items.autors (place and year) into edition_info. Dry run unless APPLY=1'
  task backfill_edition_info: :environment do
    apply = ENV['APPLY'] == '1'
    result = Library::Operation::BackfillEditionInfo.new.call(apply: apply)

    if result.failure?
      abort "backfill_edition_info FAILED, nothing was changed: #{result.failure.inspect}"
    end

    stats = result.success
    puts "Library items:            #{stats[:total]}"
    puts "With autors:              #{stats[:with_autors]}"
    puts "edition_info already set: #{stats[:already_filled]}"
    puts "To fill (candidates):     #{stats[:candidates]}"
    puts 'Sample:'
    stats[:sample].each { |row| puts "  ##{row[:number]} (id #{row[:id]}) -> #{row[:edition_info].inspect}" }

    if apply
      puts "APPLIED: #{stats[:updated]} rows updated (autors untouched)."
    else
      puts 'DRY RUN: nothing was written. Re-run with APPLY=1 to write.'
    end
  end
end
