# frozen_string_literal: true

module Training
  module Activities
    class UpdateSkiRoute
      include Dry::Monads[:result]

      def initialize(repository, form)
        @repository = repository
        @form = form
      end

      def call(id:, raw_inputs:, user_id:)
        form_outputs = form.new.call(raw_inputs.to_h)
        return Failure(form_outputs.errors(locale: :pl).to_h) unless form_outputs.success?

        route = repository.update(id: id, form_outputs: form_outputs, user_id: user_id)

        Success(:success)
      end

      private

      attr_reader :repository, :form
    end
  end
end
