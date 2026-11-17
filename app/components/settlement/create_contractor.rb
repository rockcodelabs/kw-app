# frozen_string_literal: true

module Settlement
  class CreateContractor
    include Dry::Monads[:result]

    def initialize(repository, form)
      @repository = repository
      @form = form
    end

    def call(raw_inputs:)
      form_outputs = form.new.call(raw_inputs.to_unsafe_h)
      return Failure(form_outputs.errors(full: true, locale: :pl).to_h) unless form_outputs.success?

      Success(repository.create_contractor(form_outputs: form_outputs))
    end

    private

    attr_reader :repository, :form
  end
end
