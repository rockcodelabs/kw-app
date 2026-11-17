module Management
  module Voting
    class CasesController < ApplicationController
      include EitherMatcher
      before_action :authenticate_user!
      append_view_path 'app/components'
      respond_to :html, :xlsx

      def obecni
        authorize! :obecni, Management::Voting::CaseRecord

        @obecni = Management::Voting::CasePresenceRecord.includes(:user, :cerber).where(presence_date: Date.today.all_year)
        @pelnomocnictwa = Management::Voting::CommissionRecord.includes(:authorized, :owner).where(created_at: Date.today.all_year)

        respond_with do |format| format.html
          format.xlsx do
            disposition = "attachment; filename=walne_kw_#{Time.now.strftime("%Y-%m-%d-%H%M%S")}.xlsx"
            response.headers['Content-Disposition'] = disposition
          end
        end
      end

      def walne
        authorize! :read, Management::Voting::CaseRecord

        @cases = Management::Voting::CaseRecord.where(meeting_type: 'circle').where.not(state: 'archived').order(position: :asc, acceptance_date: :asc)
        @archived_cases = Management::Voting::CaseRecord.where(meeting_type: 'circle', state: 'archived').order(position: :asc, acceptance_date: :asc)
      end

      def accept
        authorize! :read, Management::Voting::CaseRecord

        unless Date.today == '14-05-2025'.to_date
          return redirect_to walne_cases_path, alert: 'Akceptacja obecności będzie możliwa dopiero w dniu spotkania!'
        end

        unless Management::Voting::CasePresenceRecord.exists?(user_id: current_user.id, presence_date: '14-05-2025'.to_date)
          Management::Voting::CasePresenceRecord.create(user_id: current_user.id, presence_date: '14-05-2025'.to_date, accepted_terms: true)
        end

        redirect_to walne_cases_path, notice: 'Zaakceptowano warunki'
      end

      def index
        authorize! :read, Management::Voting::CaseRecord

        @cases = Management::Voting::CaseRecord.where(meeting_type: 'manage').where.not(state: 'archived').accessible_by(current_ability).order(created_at: :desc)
        @archived_cases = Management::Voting::CaseRecord.where(meeting_type: 'manage', state: 'archived').accessible_by(current_ability).order(created_at: :desc)
      end

      def new
        authorize! :create, Management::Voting::CaseRecord
        @case_record = Management::Voting::CaseRecord.new
      end

      def create
        authorize! :create, Management::Voting::CaseRecord
        either(create_record) do |result|
          result.success do
            redirect_to walne_cases_path, flash: { notice: 'Utworzono głosowanie' }
          end

          result.failure do |errors|
            @case_record = Management::Voting::CaseRecord.new(case_params)
            @errors = errors.map { |field, messages| "#{Management::Voting::CaseRecord.human_attribute_name(field)} #{messages.to_sentence}" }
            render :new
          end
        end
      end

      def edit
        @case_record = Management::Voting::CaseRecord.find(params[:id])
        authorize! :update, @case_record
      end

      def update
        @case_record = Management::Voting::CaseRecord.find(params[:id])
        authorize! :update, @case_record

        either(update_record) do |result|
          result.success do |case_id|
            redirect_to case_path(case_id), flash: { notice: 'Zaktualizowano głosowanie' }
          end

          result.failure do |errors|
            @errors = errors.map { |field, messages| "#{Management::Voting::CaseRecord.human_attribute_name(field)} #{messages.to_sentence}" }
            render :edit
          end
        end
      end

      def show
        @case = Management::Voting::CaseRecord.friendly.find(params[:id])

        authorize! :read, @case

        @repository = Management::Voting::Repository.new
      end

      def approve_for_all
        case_record = Management::Voting::CaseRecord.find(params[:id])

        repository.management_users.each do |user|
          case_record.votes.where(user_id: user.id).first_or_initialize.tap do |vote|
            vote.decision = 'approved'
            vote.save
          end
        end

        if case_record.voting? && repository.approved?(case_record.id)
          case_record.finish!
        end

        redirect_to case_path(params[:id])
      end

      def approve
        case_record = Management::Voting::CaseRecord.find(params[:id])
        user = if user_signed_in?
                 current_user
               else
                 Db::User.find(params[:user_id])
               end
        case_record.votes.where(user_id: user.id).first_or_initialize.tap do |vote|
          vote.decision = 'approved'
          vote.save
        end if user && !case_record.finished?

        redirect_to case_path(params[:id])
      end

      def unapprove
        case_record = Management::Voting::CaseRecord.find(params[:id])
        user = if user_signed_in?
                 current_user
               else
                 Db::User.find(params[:user_id])
               end
        case_record.votes.where(user_id: user.id).first_or_initialize.tap do |vote|
          vote.decision = 'unapproved'
          vote.save
        end if user && !case_record.finished?

        redirect_to case_path(params[:id])
      end

      def abstain
        case_record = Management::Voting::CaseRecord.find(params[:id])
        user = if user_signed_in?
                 current_user
               else
                 Db::User.find(params[:user_id])
               end
        case_record.votes.where(user_id: user.id).first_or_initialize.tap do |vote|
          vote.decision = 'abstained'
          vote.save
        end if user && !case_record.finished?

        redirect_to case_path(params[:id])
      end

      def hide
        case_record = Management::Voting::CaseRecord.find(params[:id])
        case_record.update hidden: true

        redirect_to case_path(params[:id])
      end

      def destroy
        case_record = Management::Voting::CaseRecord.find(params[:id])
        authorize! :destroy, Management::Voting::CaseRecord

        case_record.destroy

        redirect_to walne_cases_path, notice: 'Usunięto głosowanie'
      end

      private

      def repository
        @repository ||= Management::Voting::Repository.new
      end

      def create_record
        Management::Voting::CreateCase.new(
          Management::Voting::CaseForm
        ).call(raw_inputs: case_params)
      end

      def update_record
        Management::Voting::UpdateCase.new(
          Management::Voting::CaseForm
        ).call(id: params[:id], raw_inputs: case_params)
      end

      def case_params
        params
          .require(:case)
          .permit(:name, :position, :hidden, :number, :state, :final_voting_result, :destrciption, :meeting_type, :voting_type, :creator_id, :doc_url, :public, :hide_votes, :acceptance_date, attachments: [], who_ids: [])
      end
    end
  end
end
