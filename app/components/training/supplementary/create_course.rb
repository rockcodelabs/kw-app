require 'dry/monads'

module Training
  module Supplementary
    class CreateCourse
      include Dry::Monads[:result]

      def initialize(repository, form_class)
        @repository = repository
        @form_class = form_class
      end

      def call(raw_inputs:)
        form_outputs = form_class.new(record: Training::Supplementary::CourseRecord.new).call(normalize_nested(raw_inputs))
        return Failure(form_outputs.errors(locale: :pl).to_h) unless form_outputs.success?

        repository.create(form_outputs: form_outputs)

        Success()
      end

      private

      attr_reader :repository, :form_class

      # Rails nested forms post has_many attributes as an index-keyed hash ({ '0' => {...} }),
      # while the contract expects a list.
      def normalize_nested(raw_inputs)
        inputs = raw_inputs.to_h.symbolize_keys
        nested = inputs[:package_types_attributes]
        return inputs unless nested.is_a?(Hash)

        inputs.merge(package_types_attributes: nested.values)
      end
    end
  end
end
