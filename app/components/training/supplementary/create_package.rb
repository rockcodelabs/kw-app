# frozen_string_literal: true

module Training
  module Supplementary
    class CreatePackage
      include Dry::Monads[:result]

      def initialize(repository, form)
        @repository = repository
        @form = form
      end

      def call(raw_inputs:)
        form_outputs = form.call(raw_inputs.to_h)
        return Failure(form_outputs.errors(full: true, locale: :pl).to_h) unless form_outputs.success?

        repository.create_package(form_outputs: form_outputs)
        Success(:success)
      end

      private

      attr_reader :repository, :form
    end
  end
end
