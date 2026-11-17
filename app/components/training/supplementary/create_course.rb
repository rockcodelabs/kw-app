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
        form_outputs = form_class.new(record: Training::Supplementary::CourseRecord.new).call(raw_inputs)
        return Failure(form_outputs.errors(locale: :pl).to_h) unless form_outputs.success?

        repository.create(form_outputs: form_outputs)

        Success()
      end

      private

      attr_reader :repository, :form_class
    end
  end
end
