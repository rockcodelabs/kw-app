# frozen_string_literal: true

module Settlement
  class NewContractForm < Dry::Validation::Contract
    config.messages.load_paths << 'app/components/settlement/errors.yml'

    params do
      required(:title).filled(:string)
      required(:contractor_id).filled(:integer)
      optional(:group_type).maybe(:string)
      optional(:bank_account).maybe(:string)
      optional(:bank_account_owner).maybe(:string)
      required(:document_number).filled(:string)
      required(:document_date).filled(:string)
      optional(:document_type).maybe(:string)
      optional(:payout_type).maybe(:string)
      required(:currency_type).filled(:string)
      required(:cost).filled(:float)
      required(:description).maybe(:string)
      optional(:contract_template_id).maybe(:integer)
      required(:user_ids).each(:string)
      optional(:project_ids)
      optional(:photos_attributes)
    end

    rule(:contract_template_id, :payout_type) do
      key(:payout_type).failure(:payout_type_presence) unless template_for(values[:contract_template_id])&.payout_type || values[:payout_type]
    end

    rule(:bank_account, :payout_type) do
      key(:bank_account).failure(:bank_account_presence) if values[:payout_type] == 'return' && !values[:bank_account]
    end

    rule(:contract_template_id, :document_type) do
      key(:document_type).failure(:document_type_presence) unless template_for(values[:contract_template_id])&.document_type || values[:document_type]
    end

    rule(:contract_template_id, :group_type) do
      key(:group_type).failure(:group_type_presence) unless template_for(values[:contract_template_id])&.group_type || values[:group_type]
    end

    rule(:contract_template_id, :contractor_id, :document_type) do
      document_type = template_for(values[:contract_template_id])&.document_type || values[:document_type]

      if document_type == 'fv'
        contractor = Settlement::ContractorRecord.find_by(id: values[:contractor_id])
        key(:contractor_id).failure(:nip_if_fv) unless contractor&.nip?
      end
    end

    rule(:document_type, :photos_attributes) do
      next if values[:document_type] == 'charities'

      photos = values[:photos_attributes]
      photos = photos.values if photos.respond_to?(:values)
      key(:photos_attributes).failure(:photos_presence) unless Array(photos).reject(&:blank?).any?
    end

    rule(:contract_template_id, :project_ids) do
      if template_for(values[:contract_template_id])&.project? && Array(values[:project_ids]).reject(&:blank?).empty?
        key(:project_ids).failure(:project_presence)
      end
    end

    def template_for(id)
      Settlement::ContractTemplateRecord.find_by(id: id)
    end
  end
end
