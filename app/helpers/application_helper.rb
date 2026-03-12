module ApplicationHelper
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
