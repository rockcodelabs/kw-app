# frozen_string_literal: true

module Management
  class ProjectForm < Dry::Validation::Contract
    config.messages.load_paths << 'app/components/management/errors.yml'

    params do
      required(:name).filled(:string)
      optional(:state)
      optional(:description).maybe(:string)
      optional(:needed_knowledge).maybe(:string)
      optional(:benefits).maybe(:string)
      optional(:estimated_time).maybe(:string)
      optional(:know_how).maybe(:string)
      optional(:attachments)
      optional(:users_names)
    end
  end
end
