module Settlement
  module Admin
    class ContractsController < ::Admin::BaseController
      include EitherMatcher
      append_view_path 'app/components'
      respond_to :html, :xlsx

      def index
        authorize! :read, Settlement::ContractRecord

        status_order = params[:q]&.key?(:s) ? (params[:q][:s].include?('custom_state') ? params[:q][:s] : 'custom_state asc') : 'custom_state asc'

        @q = Settlement::ContractRecord.accessible_by(current_ability)
        @q = @q.where.not(state: ['closed']) unless params[:q]
        @q = @q.ransack(params[:q])
        @results = @q.result.order_by_state(status_order).includes([:acceptor, :creator, :checker, :contractor])
        @contracts = @results.page(params[:page])

        respond_with do |format|
          format.html
          format.xlsx do
            disposition = "attachment; filename=rozliczenia_#{Time.now.strftime("%Y-%m-%d-%H%M%S")}.xlsx"
            response.headers['Content-Disposition'] = disposition
          end
        end
      end

      def archive
        authorize! :read, Settlement::ContractRecord

        @q = Settlement::ContractRecord.accessible_by(current_ability)
        @q = @q.ransack(params[:q])

        @results = @q.result.includes([:acceptor, :creator, :checker, :contractor])
        @contracts = @results.order(updated_at: :desc).page(params[:page])

        respond_with do |format|
          format.html
          format.xlsx do
            disposition = "attachment; filename=rozliczenia_#{Time.now.strftime("%Y-%m-%d-%H%M%S")}.xlsx"
            response.headers['Content-Disposition'] = disposition
          end
        end
      end

      def history
        authorize! :read, PaperTrail::Version

        @versions = PaperTrail::Version.includes(:item).where(item_type: ["Settlement::ContractorRecord", "Settlement::ContractRecord"]).order(created_at: :desc).page(params[:page]).per(10)
      end

      def analiza
        authorize! :analiza, Settlement::ContractRecord

        start_date = Date.new(params[:year].to_i, 1, 1)
        end_date = Date.new(params[:year].to_i, 12, 31)

        @contracts = Settlement::ContractRecord.where(document_date: start_date..end_date)
      end

      def new
        authorize! :create, Settlement::ContractRecord

        @contract = Settlement::ContractRecord.new(user_ids: [current_user.id])
        session[:original_referrer] = request.env["HTTP_REFERER"]
      end

      def create
        authorize! :create, Settlement::ContractRecord

        either(create_record) do |result|
          result.success { |contract| redirect_to admin_contracts_path }

          result.failure do |errors|
            @contract = Settlement::ContractRecord.new(contract_params)
            @errors = errors
            render :new
          end
        end
      end

      def show
        @contract = Settlement::ContractRecord.find(params[:id])

        authorize! :read, @contract
        session[:original_referrer] = request.env["HTTP_REFERER"]
      end

      def destroy
        authorize! :destroy, Settlement::ContractRecord

        contract = Settlement::ContractRecord.find(params[:id])
        contract.destroy

        redirect_back(
          fallback_location: admin_contracts_path,
          notice: 'Usunięto!'
        )
      end

      def download_attachment
        contract = Settlement::ContractRecord.find(params[:id])
        authorize! :read, contract

        attachment = contract.attachments.find { |file| file.url == params[:url] }
        return redirect_to(admin_contract_path(contract), alert: 'Nie ma takiego załącznika!') unless attachment

        if attachment.file.is_a?(CarrierWave::SanitizedFile)
          send_file(attachment.file.path, filename: File.basename(attachment.file.path), disposition: 'attachment')
        else
          redirect_to attachment.url, allow_other_host: true
        end
      end

      def edit
        @contract = Settlement::ContractRecord.find(params[:id])
        authorize! :read, @contract
        session[:original_referrer] = request.env["HTTP_REFERER"]
      end

      def update
        @contract = Settlement::ContractRecord.find(params[:id])

        authorize! :update, @contract
        authorize! params[:verify].to_sym, Settlement::ContractRecord if %w[accept prepayment finish].include?(params[:verify])

        either(update_record) do |result|
          result.success do |contract|
            redirect_to edit_admin_contract_path(contract.id), notice: 'Zaktualizowano!'
          end

          result.failure do |errors|
            @errors = errors
            render :edit
          end
        end
      end

      def accept
        contract = Settlement::ContractRecord.find(params[:id])

        authorize! :accept, Settlement::ContractRecord

        return redirect_to edit_admin_contract_path(contract.id), alert: "Wypełnij pola Sekcja, Aktywność i Impreza" unless contract.activity_type && contract.group_type && contract.event_type
        return transition_not_allowed(contract) unless contract.can_accept?

        contract.update(checker_id: current_user.id)
        contract.accept!

        office_king_ids = Db::User.where(":name = ANY(roles)", name: "office_king").map(&:id)
        contract_user_ids = contract.users.map(&:id)
        recepient_ids = (office_king_ids + contract_user_ids).uniq.reject{|id| id == current_user.id }
        recepient_ids.each do |id|
          NotificationCenter::NotificationRecord.create(
            recipient_id: id,
            actor_id: current_user.id,
            action: 'accepted_contract',
            notifiable_id: contract.id,
            notifiable_type: 'Settlement::ContractRecord'
          )
        end
        ::Settlement::ContractMailer.state_changed(contract).deliver_later

        redirect_back(
          fallback_location: admin_contracts_path,
          notice: 'Sprawdzono!'
        )
      end

      def prepayment
        contract = Settlement::ContractRecord.find(params[:id])

        authorize! :prepayment, Settlement::ContractRecord

        return redirect_to edit_admin_contract_path(contract.id), alert: "Wypełnij pola Sekcja, Aktywność i Impreza" unless contract.activity_type && contract.group_type && contract.event_type
        return transition_not_allowed(contract) unless contract.can_prepayment?

        contract.prepayment!
        contract.update(acceptor_id: current_user.id, preclosed_date: Time.current)

        contract_user_ids = contract.users.map(&:id)
        recepient_ids = contract_user_ids.uniq.reject{|id| id == current_user.id }
        recepient_ids.each do |id|
          NotificationCenter::NotificationRecord.create(
            recipient_id: id,
            actor_id: current_user.id,
            action: 'prepayment_contract',
            notifiable_id: contract.id,
            notifiable_type: 'Settlement::ContractRecord'
          )
        end
        ::Settlement::ContractMailer.state_changed(contract).deliver_later

        redirect_back(
          fallback_location: admin_contracts_path,
          notice: 'Zaakceptowano!'
        )
      end

      def finish
        contract = Settlement::ContractRecord.find(params[:id])
        authorize! :finish, Settlement::ContractRecord

        return redirect_to edit_admin_contract_path(contract.id), alert: "Wypełnij pola Rodzaj wydatku, Obszar i Rodzaj działalności" unless contract.substantive_type && contract.area_type && contract.payout_type

        return transition_not_allowed(contract) unless contract.preclosed?

        contract.finish!
        contract.update(closer_id: current_user.id)
        ::Settlement::ContractMailer.state_changed(contract).deliver_later

        redirect_back(
          fallback_location: admin_contract_path(contract.id),
          notice: 'Rozliczono!'
        )
      end

      private

      def transition_not_allowed(contract)
        redirect_to admin_contract_path(contract.id), alert: 'Ta akcja nie jest możliwa dla rozliczenia w obecnym stanie.'
      end

      def create_record
        Settlement::CreateContract.new(
          Settlement::Repository.new,
          Settlement::NewContractForm
        ).call(raw_inputs: contract_params, creator_id: current_user.id)
      end

      def update_record
        Settlement::UpdateContract.new(
          Settlement::Repository.new,
          Settlement::ContractForm
        ).call(id: params[:id], raw_inputs: contract_params, verify: params[:verify], updater_id: current_user.id)
      end

      def contract_params
        params
          .require(:contract)
          .permit(
            :group_type, :payout_type, :closer_id, :acceptor_id, :event_id, :period_date, :contract_template_id, :currency_type,
            :substantive_type, :financial_type, :document_type, :area_type, :event_type, :document_date, :activity_type, :document_deliver, :accountant_deliver,
            :title, :description, :cost, :state, :document_number, :internal_number, :checker_id, :bank_account, :bank_account_owner,
            :contractor_id, attachments: [], event_ids: [], user_ids: [], project_ids: [], photos_attributes: [:file, :filename, :user_id]
          )
      end
    end
  end
end
