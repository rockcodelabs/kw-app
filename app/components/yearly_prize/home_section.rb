# frozen_string_literal: true

module YearlyPrize
  # Read-only query object behind the "Klubowa Ósemka" block on the home page.
  #
  # Works on the edition whose year equals the current year (Warsaw time), so the
  # block disappears on 1 January until the next edition is created.
  #
  # Stages: :hidden, :submissions, :voting, :voted, :results
  class HomeSection
    TIME_ZONE = 'Warsaw'
    SUMMARY_LENGTH = 200
    VOTE_TYPE = 'Db::YearlyPrizeRequest'

    CategoryGroup = Struct.new(:category, :requests)
    RankedGroup = Struct.new(:category, :entries)
    RankedEntry = Struct.new(:rank, :request)

    def initialize(user:, now: Time.current)
      @user = user
      @now = now
    end

    def edition
      return @edition if defined?(@edition)

      @edition = Db::YearlyPrizeEdition.for_year(@now.in_time_zone(TIME_ZONE).year)
    end

    def visible?
      stage != :hidden
    end

    def stage
      @stage ||=
        if edition.nil? then :hidden
        elsif edition.finished?(@now) then :results
        elsif !edition.voting_started?(@now) then :submissions
        elsif my_vote then :voted
        else :voting
        end
    end

    def categories
      @categories ||= requests.group_by(&:yearly_prize_category)
                              .sort_by { |category, _| category.id }
                              .map { |category, list| CategoryGroup.new(category, list) }
    end

    def results
      @results ||= categories.map do |group|
        sorted = group.requests.sort_by.with_index { |request, index| [-request.likes_count, index] }
        RankedGroup.new(group.category, rank(sorted))
      end
    end

    def my_vote
      return @my_vote if defined?(@my_vote)

      @my_vote = requests.find { |request| voted_request_ids.include?(request.id) }
    end

    def summary(request)
      text = request.prize_jury_description.presence || request.author_description.to_s
      ActionController::Base.helpers.strip_tags(text).squish.truncate(SUMMARY_LENGTH)
    end

    def nominees(request)
      request.users.map(&:display_name).to_sentence
    end

    def votes_label(count)
      noun =
        if count == 1 then 'głos'
        elsif (2..4).cover?(count % 10) && !(12..14).cover?(count % 100) then 'głosy'
        else 'głosów'
        end
      "#{count} #{noun}"
    end

    def deadline(time)
      time&.in_time_zone(TIME_ZONE)&.strftime('%-d.%m.%Y %H:%M')
    end

    private

    def requests
      @requests ||= edition.yearly_prize_requests
                           .includes(:users, :yearly_prize_category)
                           .order(:created_at, :id)
                           .to_a
    end

    def voted_request_ids
      @voted_request_ids ||= Like.where(user_id: @user.id, likeable_type: VOTE_TYPE, likeable_id: requests.map(&:id))
                                 .pluck(:likeable_id)
    end

    def rank(sorted_requests)
      rank = 0
      sorted_requests.each_with_index.map do |request, index|
        tied = index.positive? && sorted_requests[index - 1].likes_count == request.likes_count
        rank = index + 1 unless tied
        RankedEntry.new(rank, request)
      end
    end
  end
end
