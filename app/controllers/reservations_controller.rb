class ReservationsController < ApplicationController
  before_action :authenticate_user!

  def index
   guarded_date = Guards::Date.new(date: params[:start_date])
   return redirect_to reservations_path(start_date: guarded_date.nearest_thursday) unless guarded_date.thursday?
   return redirect_to reservations_path, alert: 'Data nie może być w przeszłości' if params[:start_date].to_date.past?
   @available_items = Availability::Items.new(start_date: params[:start_date]).collect
   @abc_1 = Availability::Items.new(start_date: params[:start_date]).collect_abc_1
   @abc_2 = Availability::Items.new(start_date: params[:start_date]).collect_abc_2
   @abc_3 = Availability::Items.new(start_date: params[:start_date]).collect_abc_3
   @axes = Availability::Items.new(start_date: params[:start_date]).collect_axes
   @crampons = Availability::Items.new(start_date: params[:start_date]).collect_crampons
   @rest = Availability::Items.new(start_date: params[:start_date]).collect_rest
  end

  def availability
    redirect_to reservations_path(start_date: params.fetch('availability_form').fetch('start_date'))
  end

  def create
   form = Reservations::Form.new(params[:reservations_form])
   result = Reservations::CreateReservation.create(form: form, user: current_user)
   result.success { redirect_to reservations_path(start_date: form.start_date.to_s), notice: 'Zarezerwowano przedmiot.' }
   result.form_invalid { |form:| redirect_to root_path, alert: "Nie dodano z powodu: #{form.errors.messages}" }
   result.item_already_reserved { |form:| redirect_to reservations_path(start_date: form.start_date.to_s), alert: 'Przedmiot został już zarezerwowany w tym okresie.'}
   result.else_fail!
  end

  def delete_item
    result = Reservations::CancelItem.from(reservation_id: params[:id]).delete(item_id: params[:item_id])
    result.success do |start_date:|
      redirect_to reservations_path(start_date: start_date), notice: 'Zrezygnowano z rezerwacji przedmiotu.'
    end
    result.item_not_exist { redirect_back(fallback_location: root_path, alert: 'Przedmiot nie istnieje.') }
    result.reservation_not_exist { redirect_back(fallback_location: root_path, alert: 'Przedmiot nie istnieje.') }
    result.else_fail!
  end
end
