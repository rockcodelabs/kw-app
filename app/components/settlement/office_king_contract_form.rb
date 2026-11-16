# frozen_string_literal: true

require 'i18n'
require 'dry-validation'

module Settlement
  class OfficeKingContractForm < Dry::Validation::Contract
    config.messages.load_paths << 'app/components/settlement/errors.yml'

    option :record
    option :verify

    params do
      required(:title).filled(:string)
      required(:cost).filled(:float)
      required(:document_type).filled
      required(:payout_type).filled
      required(:internal_number).filled
      required(:document_date).filled(:string)
      required(:document_number).filled(:string)
      required(:description).maybe(:string)
      optional(:document_deliver)
      optional(:accountant_deliver)
      optional(:attachments)
      optional(:photos_attributes)
      optional(:group_type)
      optional(:activity_type)
      optional(:event_type)
      optional(:area_type)
      optional(:acceptor_id)
      optional(:checker_id)
      optional(:closer_id)
      optional(:substantive_type)
      optional(:state)
      optional(:financial_type)
      optional(:period_date)
      required(:user_ids).each(:string)
      optional(:project_ids)
      optional(:contractor_id).maybe(:integer)
      optional(:'period_date(1i)')
      optional(:'period_date(2i)')
    end

    rule(:internal_number, :'period_date(1i)') do
      year = values[:'period_date(1i)']

      if year.present? && record.class.where.not(id: record.id).where(period_date: "01-01-#{year}", internal_number: values[:internal_number]).exists?
        key(:internal_number).failure(:internal_number_uniq)
      end
    end

    rule(:state, :checker_id) do
      key(:checker_id).failure(:accepted_group) if %w[accepted preclosed closed].include?(values[:state]) && values[:checker_id].blank?
    end

    rule(:state, :acceptor_id) do
      key(:acceptor_id).failure(:preclosed_group) if %w[preclosed closed].include?(values[:state]) && values[:acceptor_id].blank?
    end

    rule(:activity_type, :group_type, :event_type, :state) do
      if %w[accepted preclosed closed].include?(values[:state]) || %w[accept prepayment].include?(verify)
        unless values[:activity_type].present? && values[:group_type].present? && values[:event_type].present?
          key(:activity_type).failure(:accepted_fields)
        end
      end
    end

    rule(:substantive_type, :financial_type, :area_type, :state) do
      if values[:state] == 'closed' || verify == 'finish'
        unless values[:substantive_type].present? && values[:financial_type].present? && values[:area_type].present?
          key(:substantive_type).failure(:closed_fields)
        end
      end
    end
  end
end
