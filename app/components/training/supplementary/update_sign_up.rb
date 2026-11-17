# frozen_string_literal: true

module Training
  module Supplementary
    class UpdateSignUp
      include Dry::Monads[:result]

      def initialize(repository, form)
        @repository = repository
        @form = form
      end

      def call(id:, raw_inputs:)
        form_outputs = form.call(raw_inputs.to_h)
        return Failure(form_outputs.errors(locale: :pl).to_h) unless form_outputs.success?

        sign_up = Training::Supplementary::SignUpRecord.find(id)
        sign_up.update(form_outputs.to_h)
        sign_up.update(
          name: sign_up.user.display_name,
          email: sign_up.user.email
        ) if sign_up.user

        Success(:success)
      end

      private

      attr_reader :repository, :form
    end
  end
end
