# == Schema Information
#
# Table name: contracts
#
#  id                   :bigint           not null, primary key
#  accountant_deliver   :boolean          default(FALSE), not null
#  activity_type        :integer
#  area_type            :integer
#  attachments          :string
#  bank_account         :string
#  bank_account_owner   :string
#  closed_at            :datetime
#  cost                 :float
#  currency_type        :integer          default("pln"), not null
#  description          :text
#  document_date        :date
#  document_deliver     :boolean          default(FALSE), not null
#  document_number      :string
#  document_type        :integer
#  event_type           :integer
#  financial_type       :integer
#  group_type           :integer
#  internal_number      :integer
#  payout_type          :integer
#  period_date          :date
#  preclosed_date       :datetime
#  state                :string           default("new"), not null
#  substantive_type     :integer
#  title                :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  acceptor_id          :integer
#  checker_id           :integer
#  closer_id            :integer
#  contract_template_id :integer
#  contractor_id        :integer
#  creator_id           :integer          not null
#  event_id             :integer
#  preacceptor_id       :integer
#
# Indexes
#
#  index_contracts_on_internal_number_and_period_date  (internal_number,period_date) UNIQUE
#
module Settlement
  class ContractRecord < ActiveRecord::Base
    include Workflow

    self.table_name = 'contracts'
    has_paper_trail
    mount_uploaders :attachments, Settlement::AttachmentUploader
    serialize :attachments, JSON

    enum document_type: [:fv, :work, :service, :bill, :volunteering, :charities, :taxes, :insurance_policy]
    enum payout_type: [:to_contractor, :return, :credit_card]
    enum currency_type: [:pln, :eur, :usd]
    enum group_type: [:kw, :snw, :sww, :stj]
    enum event_type: [:not_event, :other_event, :mjs, :mas, :mo, :kfg]
    enum activity_type: [:courses, :competitions, :other_activity, :maintenance, :supplementary_trainings]
    enum substantive_type: [:salary, :other_substantive, :materials, :equipment, :finantial_costs, :rewards, :printing, :insurance]
    enum area_type: [:marketing, :it, :accomodation, :administration, :reservations, :training, :image, :integration, :associations, :mountain_actions, :general, :library]
    enum financial_type: [:opp_paid, :opp_unpaid, :internal, :economic_activity]

    belongs_to :contract_template, class_name: 'Settlement::ContractTemplateRecord', optional: true

    belongs_to :acceptor, class_name: 'Db::User', foreign_key: :acceptor_id
    belongs_to :closer, class_name: 'Db::User', foreign_key: :closer_id
    belongs_to :checker, class_name: 'Db::User', foreign_key: :checker_id
    belongs_to :creator, class_name: 'Db::User', foreign_key: :creator_id
    belongs_to :contractor, class_name: 'Settlement::ContractorRecord', foreign_key: :contractor_id

    has_many :contract_events, class_name: 'Settlement::ContractEventsRecord', foreign_key: :contract_id
    has_many :events, class_name: 'Training::Supplementary::CourseRecord', through: :contract_events, foreign_key: :event_id, dependent: :destroy

    has_many :contract_users, class_name: 'Settlement::ContractUsersRecord', foreign_key: :contract_id
    has_many :users, through: :contract_users, foreign_key: :user_id, dependent: :destroy

    has_many :comments, as: :commentable, class_name: 'Messaging::CommentRecord'

    has_many :project_items, as: :accountable, class_name: '::Settlement::ProjectItemRecord'
    has_many :projects, through: :project_items

    has_many :photos, as: :uploadable, class_name: 'Storage::UploadRecord'
    accepts_nested_attributes_for :photos, reject_if: proc { |attributes| attributes[:file].blank? }

    STATUS_ASC_ORDERS = ['new', 'accepted', 'preclosed', 'closed'].freeze
    STATUS_DESC_ORDERS = STATUS_ASC_ORDERS.reverse.freeze
    STATUSES_ORDER_MAP = { "custom_state asc" => STATUS_ASC_ORDERS, "custom_state desc" => STATUS_DESC_ORDERS}

    scope :order_by_state, -> (status_order) {
      order_by = ['CASE']
      STATUSES_ORDER_MAP.fetch(status_order, STATUS_ASC_ORDERS).each_with_index do |status, index|
        order_by << "WHEN state='#{status}' THEN #{index}"
      end
      order_by << 'END'
      order(Arel.sql(order_by.join(' '))).order(created_at: :desc)
    }

    def self.ransortable_attributes(auth_object = nil)
        ransackable_attributes(auth_object) + %w(
          order_by_state
        )
    end

    workflow_column :state
    workflow do
      state :new do
        event :accept, :transitions_to => :accepted
      end
      state :accepted do
        event :prepayment, :transitions_to => :preclosed
      end
      state :preclosed do
        event :finish, :transitions_to => :closed
      end
      state :closed
    end

    def number
      "#{internal_number}/#{period_date.year}"
    end

    class << self
      Settlement::ContractRecord.defined_enums.keys.each do |method|
        define_method "search_#{method}s_select" do
          Settlement::ContractRecord.send("#{method}s").map { |name, value| [I18n.t(name, scope: "activerecord.attributes.settlement/contract_record.#{method}s"), value] }
        end
      end
      Settlement::ContractRecord.defined_enums.keys.each do |method|
        define_method "#{method}s_select" do
          Settlement::ContractRecord.send("#{method}s").map { |name, value| [I18n.t(name, scope: "activerecord.attributes.settlement/contract_record.#{method}s"), name] }
        end
      end
    end

    def self.states_select
      Settlement::ContractRecord.workflow_spec.states.map { |w, _| [I18n.t(w, scope: 'activerecord.attributes.settlement/contract_record.states'), w] }
    end

    def contractor_name=(id)
      self.contractor_id = id
    end

    attr_reader :contractor_name
  end
end
