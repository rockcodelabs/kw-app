# frozen_string_literal: true

module Management
  class CreateProject
    include Dry::Monads[:result]

    def initialize(form)
      @form = form
    end

    def call(raw_inputs:)
      form_outputs = form.new.call(raw_inputs.to_unsafe_h)
      return Failure(form_outputs.errors(locale: :pl).to_h) unless form_outputs.success?

      Management::ProjectRecord.create(form_outputs.to_h)

      Success(:success)
    end

    private

    attr_reader :form
  end
end
