class LikesController < ApplicationController
  def create
    case like_params[:likeable_type]
    when  "PhotoCompetition::RequestRecord"
      edition = PhotoCompetition::RequestRecord.find(like_params[:likeable_id]).edition

      if edition.finished?
        return redirect_back(fallback_location: root_path, alert: 'Głosowanie w tej edycji zakończyło się!')
      end

      if current_user.likes.where(likeable_type: "PhotoCompetition::RequestRecord").select{|like| like.likeable.edition == edition}.count >= 3
        return redirect_back(fallback_location: root_path, alert: 'Możesz oddać tylko 3 głosy w tej edycji!')
      end
    when  "Db::YearlyPrizeRequest"
      edition = Db::YearlyPrizeRequest.find(like_params[:likeable_id]).yearly_prize_edition

      if edition.finished?
        return redirect_back(fallback_location: root_path, alert: 'Głosowanie w tej edycji zakończyło się!')
      end

      if current_user.likes.where(likeable_type: "Db::YearlyPrizeRequest").select{|like| like.likeable.yearly_prize_edition == edition}.count >= 1
        return redirect_back(fallback_location: root_path, alert: 'Możesz oddać tylko 1 głos w tej edycji!')
      end
    end

    @like = current_user.likes.new(like_params)
    @like.save

    redirect_back(fallback_location: root_path)
  end

  def destroy
    @like = current_user.likes.find(params[:id])
    @like.destroy

    redirect_back(fallback_location: root_path)
  end

  private

  def like_params
    params.require(:like).permit(:likeable_id, :likeable_type)
  end
end
