module Settlement
  module Admin
    class ContractorsController < ::Admin::BaseController
      include EitherMatcher
      append_view_path 'app/components'

      def index
        @q = Settlement::ContractorRecord.all
        @q = @q.ransack(params[:q])
        @q.sorts = ['updated_at desc', 'name desc'] if @q.sorts.empty?
        @contractors = @q.result(distinct: true).includes([:contracts]).page(params[:page])
      end

      def new
        authorize! :create, Settlement::ContractorRecord

        @contractor = Settlement::ContractorRecord.new
      end

      def create
        authorize! :create, Settlement::ContractorRecord

        either(create_record) do |result|
          result.success do |a|
            if params[:quick]
              @contractor = Settlement::ContractorRecord.new(contractor_params)
              flash[:notice] = "Dodano kontrahenta"
              params[:quick] = true
              render :new
            else
              if contractor_params[:back_url] == 'sponsorship_requests'
                redirect_to sponsorship_requests_path, notice: 'Dodano'
              elsif contractor_params[:back_url] == 'new_sponsorship_request'
                redirect_to new_sponsorship_request_path, notice: 'Dodano'
              else
                redirect_to admin_contractors_path, notice: 'Dodano'
              end
            end
          end

          result.failure do |errors|
            @contractor = Settlement::ContractorRecord.new(contractor_params)
            flash[:error] = errors.values.join(", ")
            render :new
          end
        end
      end

      def show
        @contractor = Settlement::ContractorRecord.find(params[:id])
        @q = @contractor.contracts
        @q = @q.ransack(params[:q])
        @q.sorts = ['updated_at desc', 'document_date desc'] if @q.sorts.empty?
        @contracts = @q.result(distinct: true).page(params[:page])
      end

      def edit
        authorize! :manage, Settlement::ContractorRecord

        @contractor = Settlement::ContractorRecord.find(params[:id])
      end

      def update
        authorize! :manage, Settlement::ContractorRecord

        @contractor = Settlement::ContractorRecord.find(params[:id])

        if @contractor.update(contractor_params)
          redirect_to admin_contractor_path(@contractor.id), notice: 'Zaktualizowano'
        else
          render :edit
        end
      end

      def destroy
        authorize! :destroy, Settlement::ContractorRecord

        contract = Settlement::ContractorRecord.find(params[:id])
        contract.destroy

        redirect_back(
          fallback_location: admin_contractors_path,
          notice: 'Usunięto!'
        )
      end

      private

      def create_record
        Settlement::CreateContractor.new(
          Settlement::Repository.new,
          Settlement::ContractorForm
        ).call(raw_inputs: contractor_params)
      end

      def contractor_params
        params
          .require(:contractor)
          .permit(:name, :description, :logo, :nip, :back_url, :email, :www, :contact_name, :reason_type, :profession_type, :phone)
      end
    end
  end
end
