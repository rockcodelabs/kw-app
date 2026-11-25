# frozen_string_literal: true

module PhotoCompetition
  # Read-only query object behind the "Konkurs Fotograficzny" block on the home page.
  #
  # Works on the edition coded kasprzyk_<current year> (Warsaw time), so the block
  # disappears on 1 January until the next edition is created.
  #
  # Stages: :hidden, :submissions, :voting, :results
  class HomeSection
    include HomeSections::Formatting

    MAX_VOTES = 3
    DAILY_PICKS = 4
    TOP_PER_CATEGORY = 3
    VOTE_TYPE = 'PhotoCompetition::RequestRecord'

    RankedGroup = Struct.new(:category, :entries)
    RankedEntry = Struct.new(:rank, :photo)

    def initialize(user:, now: Time.current)
      @user = user
      @now = now
    end

    def edition
      return @edition if defined?(@edition)

      @edition = EditionRecord.for_year(local_now.year)
    end

    def visible?
      stage != :hidden
    end

    def stage
      @stage ||=
        if edition.nil? then :hidden
        elsif edition.finished?(@now) then :results
        elsif !edition.voting_started?(@now) then :submissions
        else :voting
        end
    end

    def categories
      edition.categories.order(:id).to_a
    end

    def my_votes
      @my_votes ||= edition.photo_requests.where(id: voted_ids).order(:id).to_a
    end

    def votes_left
      [MAX_VOTES - voted_ids.size, 0].max
    end

    # A few accepted photos the user has not voted for yet; stable during a day, different the next day.
    def daily_picks
      @daily_picks ||=
        if votes_left.zero?
          []
        else
          ids = edition.photo_requests.where(accepted: true).where.not(id: voted_ids).order(:id).pluck(:id)
          picked = ids.sample(DAILY_PICKS, random: Random.new((local_now.to_date.jd * 1000) + edition.id))
          records = edition.photo_requests.where(id: picked).index_by(&:id)
          picked.filter_map { |id| records[id] }
        end
    end

    def results
      @results ||= accepted_photos.group_by(&:category).sort_by { |category, _| category.id }.map do |category, list|
        RankedGroup.new(category, rank(list.first(TOP_PER_CATEGORY)))
      end
    end

    def gallery_path
      "/konkurs/#{edition.code}/glosowanie"
    end

    def submit_path
      "/konkurs/#{edition.code}"
    end

    def photo_path(photo)
      "/editions/#{edition.code}/requests/#{photo.id}"
    end

    private

    def local_now
      @now.in_time_zone(TIME_ZONE)
    end

    def voted_ids
      @voted_ids ||= Like.where(user_id: @user.id, likeable_type: VOTE_TYPE, likeable_id: edition.photo_requests.select(:id))
                         .pluck(:likeable_id)
    end

    def accepted_photos
      edition.photo_requests.where(accepted: true).includes(:category, :user).order(likes_count: :desc, id: :asc)
    end

    def rank(sorted_photos)
      rank = 0
      sorted_photos.each_with_index.map do |photo, index|
        tied = index.positive? && sorted_photos[index - 1].likes_count == photo.likes_count
        rank = index + 1 unless tied
        RankedEntry.new(rank, photo)
      end
    end
  end
end
