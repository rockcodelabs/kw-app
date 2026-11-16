# frozen_string_literal: true

module Settlement
  class UpdateContract
    include Dry::Monads[:result]

    def initialize(repository, form)
      @repository = repository
      @form = form
    end

    def call(id:, raw_inputs:, verify:, updater_id:)
      contract = Settlement::ContractRecord.find(id)
      form_class = if Db::User.find_by(id: updater_id)&.roles&.include?('office_king')
                     ::Settlement::OfficeKingContractForm
                   else
                     form
                   end
      form_outputs = form_class.new(record: contract, verify: verify).call(raw_inputs.to_h)
      return Failure(form_outputs.errors(locale: :pl).to_h) unless form_outputs.success?

      attributes = form_outputs.to_h.dup
      period_date_month = attributes.delete(:"period_date(2i)").try :to_i
      period_date_year = attributes.delete(:"period_date(1i)").try :to_i
      contract.update(attributes)
      contract.update(
        period_date: Date.civil(period_date_year, period_date_month, 1)
      ) if period_date_month && period_date_year
      contract.update(contractor_id: attributes[:contractor_name].first.to_i) if attributes.key?(:contractor_name)

      if attributes[:activity_type].present? && attributes[:group_type].present? && attributes[:event_type].present? && !contract.checker_id && contract.new?
        contract.update(
          checker_id: updater_id, state: 'accepted'
        )
        ::Settlement::ContractMailer.state_changed(contract).deliver_later
      end

      if verify == 'prepayment'
        contract.update(acceptor_id: updater_id, state: 'preclosed')
        ::Settlement::ContractMailer.state_changed(contract).deliver_later
      end

      if verify == 'finish'
        ::Settlement::ContractMailer.state_changed(contract).deliver_later
        contract.update(state: 'closed', closer_id: updater_id)
      end

      unless contract.closed_at.present?
        if attributes[:document_deliver] == '1' && attributes[:accountant_deliver] == '1'
          contract.update(closed_at: Time.current)
        end if raw_inputs.key?(:document_deliver) && raw_inputs.key?(:accountant_deliver)
      end

      office_king_ids = Db::User.where(":name = ANY(roles)", name: "office_king").map(&:id)
      financial_ids = Db::User.where(":name = ANY(roles)", name: "financial_management").map(&:id)
      contract_user_ids = contract.users.map(&:id)
      recepient_ids = (financial_ids + office_king_ids + contract_user_ids).uniq.reject { |recipient_id| recipient_id == updater_id }
      recepient_ids.each do |recipient_id|
        NotificationCenter::NotificationRecord.create(
          recipient_id: recipient_id,
          actor_id: updater_id,
          action: 'updated_contract',
          notifiable_id: contract.id,
          notifiable_type: 'Settlement::ContractRecord'
        )
      end

      Success(contract)
    end

    private

    attr_reader :repository, :form
  end
end
