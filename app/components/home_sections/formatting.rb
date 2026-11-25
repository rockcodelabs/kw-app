# frozen_string_literal: true

module HomeSections
  # Display helpers shared by the home page presenters (Klubowa Ósemka, Konkurs Fotograficzny).
  module Formatting
    TIME_ZONE = 'Warsaw'

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
  end
end
