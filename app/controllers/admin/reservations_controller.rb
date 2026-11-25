module Admin
  class ReservationsController < Admin::BaseController
    append_view_path 'app/components'

    def index
      @q = Db::Reservation.ransack(params[:q])
      @reservations = if params[:archived]
        @q.result.where(state: 'archived').includes(:user, :items).page(params[:page])
      else
        @q.result.where.not(state: 'archived').includes(:user, :items).page(params[:page])
      end

      authorize! :manage, Db::Reservation

      respond_to do |format|
        format.html
        format.xlsx do
          disposition = "attachment; filename='rezerwacje_#{Time.now.strftime("%Y-%m-%d-%H%M%S")}.xlsx'"
          response.headers['Content-Disposition'] = disposition
        end
      end
    end

    def create
      authorize! :create, Db::Reservation

      result = Admin::Reservations.new(reservation_params).create
      result.success { redirect_to admin_reservations_path, notice: 'Dodano' }
      result.invalid { |form:| redirect_to admin_reservations_path, alert: "Nie dodano: #{form.errors.messages}" }
      result.else_fail!
    end

    def edit
      @reservation = Db::Reservation.find(params[:id])
      authorize! :manage, Db::Reservation
      @reservation_form = Admin::ReservationsForm.new(@reservation.slice(:kw_id, :end_date, :start_date, :remarks))
    end

    def update
      authorize! :manage, Db::Reservation
      result = Admin::Reservations.new(reservation_params).update(params[:id])
      result.success { redirect_to edit_admin_reservation_path(params[:id]), notice: 'Zaktualizowano' }
      result.invalid { |form:| redirect_to edit_admin_reservation_path(params[:id]), alert: "Nie zaktualizowano bo: #{form.errors.messages}" }
      result.else_fail!
    end

    def archive
      authorize! :archive, Db::Reservation
      reservation = Db::Reservation.find(params[:id])
      return redirect_to admin_reservations_path, alert: 'Rezerwacja jest już oddana' unless reservation.can_archive?

      reservation.archive!

      redirect_to admin_reservations_path, notice: 'Oznaczono jako oddane'
    end

    def give
      authorize! :give, Db::Reservation

      reservation = Db::Reservation.find(params[:id])
      return redirect_to admin_reservations_path, alert: 'Rezerwacja jest już przekazana lub oddana' unless reservation.can_give?

      reservation.give!

      redirect_to admin_reservations_path, notice: "Oznaczono jako w posiadaniu."
    end

    def charge
      authorize! :charge, Db::Reservation

      reservation = Db::Reservation.find(params[:id])
      reservation.payment.update(cash: true) if reservation.payment

      redirect_to edit_admin_reservation_path(reservation), notice: "Oznaczono jako zapłacone gotowką"
    end

    def remind
      authorize! :remind, Db::Reservation

      reservation = Db::Reservation.find(params[:id])
      ReservationMailer.remind(reservation).deliver_later
      redirect_to admin_reservations_path, notice: 'Przypomniano i wysłano email'
    end

    def give_warning
      authorize! :give_warning, Db::Reservation

      reservation = Db::Reservation.find(params[:id])
      reservation.user.increment(:warnings)
      reservation.user.save
      redirect_to edit_admin_reservation_path(reservation), alert: 'Dodano ostrzezenie'
    end

    def give_back_warning
      authorize! :give_back_warning, Db::Reservation

      reservation = Db::Reservation.find(params[:id])
      reservation.user.decrement(:warnings)
      reservation.user.save
      redirect_to edit_admin_reservation_path(reservation), success: 'Usunieto ostrzezenie'
    end

    def destroy
      authorize! :destroy, Db::Reservation

      result = Admin::Reservations.destroy(params[:id])
      result.success { redirect_to admin_reservations_path, notice: 'Usunieto' }
      result.failure { redirect_to admin_reservations_path, alert: 'Nie usunieto' }
      result.else_fail!
    end

    private

    def authorize_admin
      redirect_to root_url, alert: 'Nie jestes administratorem!' unless user_signed_in? && (current_user.roles.include?('reservations') || current_user.admin?)
    end

    def reservation_params
      params.require(:admin_reservations_form).permit(:kw_id, :item_id, :start_date, :end_date, :remarks, photos: [])
    end
  end
end
