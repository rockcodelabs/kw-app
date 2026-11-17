# frozen_string_literal: true

module Management
  class UpdateProject
    include Dry::Monads[:result]

    def initialize(form)
      @form = form
    end

    def call(id:, raw_inputs:)
      form_outputs = form.new.call(raw_inputs.to_unsafe_h)
      return Failure(form_outputs.errors(locale: :pl).to_h) unless form_outputs.success?

      project = Management::ProjectRecord.find_by(id: id)
      return Failure(base: ['projekt nie został znaleziony']) unless project

      project.update(form_outputs.to_h)

      Success(project)
    end

    private

    attr_reader :form
  end
end
