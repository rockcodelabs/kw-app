module Training
  module Questionare
    class SnwProfileService
      include Dry::Monads[:result]

      def initialize(repository, form)
        @repository = repository
        @form = form
      end

      def create(raw_inputs)
        form_outputs = @form.call(raw_inputs)
        return Failure(form_outputs.messages(full: true)) unless form_outputs.success?
        repository.create(form_outputs)
        Success(:success)
      end
    end
  end
end
