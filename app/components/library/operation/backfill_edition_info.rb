# frozen_string_literal: true

module Library
  module Operation
    # Copies `autors` (which holds place and year of the edition, not authors) into the new `edition_info`
    # column. See docs/LIBRARY_INVENTORY_PLAN.md, decision 12 and step 4.
    #
    # - Dry run by default: with `apply: false` it only counts and returns a sample, nothing is written.
    # - Only fills blanks: an `edition_info` that already has a value is never overwritten.
    # - `autors` is never changed (kept for rollback) and `updated_at` is not touched.
    # - A single UPDATE inside a transaction, so it is all or nothing, and running it twice changes nothing.
    # - Uses SQL (`update_all`) on purpose: some old rows may not satisfy the newer model validations.
    class BackfillEditionInfo
      include Dry::Monads[:result]

      SAMPLE_SIZE = 10

      # @param apply [Boolean] false (default) = dry run, true = write
      # @return [Dry::Monads::Result] Success(Hash with counts and sample) or Failure(Hash)
      def call(apply: false)
        stats = collect_stats
        return Success(stats.merge(applied: false, updated: 0)) unless apply

        updated = write_candidates(stats[:candidates])
        Success(stats.merge(applied: true, updated: updated))
      rescue ActiveRecord::ActiveRecordError => e
        Failure(error: e.class.name, message: e.message)
      end

      private

      def items
        Library::ItemRecord
      end

      def candidates_scope
        items.where("BTRIM(COALESCE(autors, '')) <> ''")
             .where("BTRIM(COALESCE(edition_info, '')) = ''")
      end

      def collect_stats
        {
          total: items.count,
          with_autors: items.where("BTRIM(COALESCE(autors, '')) <> ''").count,
          already_filled: items.where("BTRIM(COALESCE(edition_info, '')) <> ''").count,
          candidates: candidates_scope.count,
          sample: sample
        }
      end

      def sample
        candidates_scope.order(:item_id, :id).limit(SAMPLE_SIZE).pluck(:id, :item_id, :autors).map do |id, number, autors|
          { id: id, number: number, edition_info: autors.strip }
        end
      end

      def write_candidates(expected)
        updated = 0
        ActiveRecord::Base.transaction(requires_new: true) do
          updated = candidates_scope.update_all("edition_info = BTRIM(autors)")
          raise ActiveRecord::Rollback if updated != expected
        end
        raise ActiveRecord::RecordNotSaved, "expected #{expected} rows, updated #{updated}, rolled back" if updated != expected

        updated
      end
    end
  end
end
