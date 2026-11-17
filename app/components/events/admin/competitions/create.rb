# frozen_string_literal: true

module Events
  module Admin
    module Competitions
      class Create
        include Dry::Monads[:result]

        def initialize(competitions_repository, create_competition_form)
          @competitions_repository = competitions_repository
          @create_competition_form = create_competition_form
        end

        def call(raw_inputs:)
          form_outputs = create_competition_form.call(raw_inputs.to_h)
          return Failure(form_outputs.errors(full: true, locale: :pl).to_h) unless form_outputs.success?

          competitions_repository.create(form_outputs: form_outputs)
          Success(:success)
        end

        private

        attr_reader :competitions_repository, :create_competition_form
      end
    end
  end
end
