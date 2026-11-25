module ApplicationHelper
  URL_REGEX = %r{https?://[^\s<]+}i.freeze
  URL_TRAILING_PUNCTUATION = /[.,;:!?)\]]+\z/.freeze

  # Like simple_format, but turns plain http(s) URLs into clickable links.
  # Input is HTML-escaped first, so user text cannot inject markup.
  def simple_format_with_links(text)
    escaped = ERB::Util.html_escape(text.to_s)
    linked = escaped.gsub(URL_REGEX) do |url|
      trailing = url[URL_TRAILING_PUNCTUATION].to_s
      clean = url.delete_suffix(trailing)
      link_to(clean, clean, target: '_blank', rel: 'noopener noreferrer') + trailing
    end
    simple_format(linked.html_safe, {}, sanitize: false)
  end

  def sort_link_for(col, label, current_sort, current_dir, year)
    is_active = current_sort == col
    next_dir = (is_active && current_dir == 'desc') ? 'asc' : 'desc'
    arrow = is_active ? (current_dir == 'desc' ? ' ▼' : ' ▲') : ' ⇅'
    link_to liga_tradowa_path(year: year, sort: col, dir: next_dir),
            style: "text-decoration: none; color: #{is_active ? '#1a73e8' : 'inherit'}; white-space: nowrap;" do
      "#{label}#{content_tag(:span, arrow, style: 'font-size: 0.75rem; opacity: 0.7;')}".html_safe
    end
  end
end
