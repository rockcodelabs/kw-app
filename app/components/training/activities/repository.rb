module Training
  module Activities
    class Repository
      def create(form_outputs:, user_id:)
        record = ::Db::Activities::MountainRoute
          .new(form_outputs.to_h)
        record.user_id = user_id
        record.save

        Training::Activities::SkiRoute.from_record(record)
      end

      def update(id:, form_outputs:, user_id:)
        record = ::Db::Activities::MountainRoute.find(id)
        record.update(form_outputs.to_h)

        Training::Activities::SkiRoute.from_record(record)
      end

      def choose_winer_from_last_month
        range = Time.now.prev_month.beginning_of_month..Time.now.prev_month.end_of_month
        routes = ::Db::Activities::MountainRoute
          .where(
            route_type: 'ski',
            climbing_date: range,
            created_at: Time.now.prev_month.beginning_of_month..(Time.now.prev_month.end_of_month + 2.days)
        ).select {|r| r.attachments.any? }
        users_ids = routes.collect(&:colleagues).flatten.map(&:id)
        users = ::Db::User.where(id: users_ids, boars: true)
        users.sample
      end

      def fetch_autum
        range_climbing_date = start_date..start_date.end_of_year
        range_created_at = start_date..(start_date.end_of_year + 2.days)
        ::Db::User
          .joins(:mountain_routes)
          .where.not(mountain_routes: { id: nil })
          .where.not(mountain_routes: { length: nil })
          .where(boars: true, mountain_routes: { route_type: 'ski', climbing_date: range_climbing_date, created_at: range_created_at})
          .select('users.kw_id, users.id, SUM(mountain_routes.length)')
          .group('users.id')
          .distinct
          .order('SUM(mountain_routes.length) DESC')
      end

      def fetch_winter
        range_climbing_date = start_date.next_year.beginning_of_year..(start_date.next_year.beginning_of_year + 1.month).end_of_month
        range_created_at = start_date.next_year.beginning_of_year..((start_date.next_year.beginning_of_year + 1.month).end_of_month + 2.days)
        ::Db::User
          .joins(:mountain_routes)
          .where.not(mountain_routes: { id: nil })
          .where.not(mountain_routes: { length: nil })
          .where(boars: true, mountain_routes: { route_type: 'ski', climbing_date: range_climbing_date, created_at: range_created_at })
          .select('users.kw_id, users.id, SUM(mountain_routes.length)')
          .group('users.id')
          .distinct
          .order('SUM(mountain_routes.length) DESC')
      end

      def fetch_spring
        range_climbing_date = (start_date.next_year.beginning_of_year + 2.months).beginning_of_month..(start_date.next_year.beginning_of_year + 3.months).end_of_month
        range_created_at = (start_date.next_year.beginning_of_year + 2.months).beginning_of_month..((start_date.next_year.beginning_of_year + 3.months).end_of_month + 2.days)
        ::Db::User
          .joins(:mountain_routes)
          .where.not(mountain_routes: { id: nil })
          .where.not(mountain_routes: { length: nil })
          .where(boars: true, mountain_routes: { route_type: 'ski', climbing_date: range_climbing_date, created_at: range_created_at })
          .select('users.kw_id, users.id, SUM(mountain_routes.length)')
          .group('users.id')
          .distinct
          .order('SUM(mountain_routes.length) DESC')
      end

      def fetch_prev_prev_month
        range_climbing_date = Time.now.prev_month.beginning_of_month..Time.now.prev_month.end_of_month
        range_created_at = Time.now.prev_month.beginning_of_month..(Time.now.prev_month.end_of_month + 2.days)
        ::Db::User
          .joins(:mountain_routes)
          .where.not(mountain_routes: { id: nil })
          .where.not(mountain_routes: { length: nil })
          .where(boars: true, mountain_routes: { route_type: 'ski', climbing_date: range_climbing_date, created_at: range_created_at })
          .select('users.kw_id, users.id, SUM(mountain_routes.length)')
          .group('users.id')
          .distinct
          .order('SUM(mountain_routes.length) DESC')
      end

      def fetch_prev_month
        range_climbing_date = Time.now.prev_month.beginning_of_month..Time.now.prev_month.end_of_month
        range_created_at = Time.now.prev_month.beginning_of_month..(Time.now.prev_month.end_of_month + 2.days)
        ::Db::User
          .joins(:mountain_routes)
          .where.not(mountain_routes: { id: nil })
          .where.not(mountain_routes: { length: nil })
          .where(boars: true, mountain_routes: { route_type: 'ski', climbing_date: range_climbing_date, created_at: range_created_at })
          .select('users.kw_id, users.id, SUM(mountain_routes.length)')
          .group('users.id')
          .distinct
          .order('SUM(mountain_routes.length) DESC')
      end

      def fetch_current_month
        range = Time.now.beginning_of_month..Time.now.end_of_month
        ::Db::User
          .joins(:mountain_routes)
          .where.not(mountain_routes: { id: nil })
          .where.not(mountain_routes: { length: nil })
          .where(boars: true, mountain_routes: { route_type: 'ski', climbing_date: range, created_at: range })
          .select('users.kw_id, users.id, SUM(mountain_routes.length)')
          .group('users.id')
          .distinct
          .order('SUM(mountain_routes.length) DESC')
      end

      def fetch_season
        range = start_date..end_date
        ::Db::User
          .joins(:mountain_routes)
          .where.not(mountain_routes: { id: nil })
          .where.not(mountain_routes: { length: nil })
          .where(boars: true, mountain_routes: { route_type: 'ski', climbing_date: range, created_at: range })
          .select('users.kw_id, users.id, SUM(mountain_routes.length)')
          .group('users.id')
          .distinct
          .order('SUM(mountain_routes.length) DESC')
      end

      def start_date
        start_date = DateTime.new(2025, 12, 1)
      end

      def end_date
        end_date = DateTime.new(2026, 5, 1)
      end
    end
  end
end
