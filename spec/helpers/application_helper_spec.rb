# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#simple_format_with_links' do
    it 'turns URLs into links and keeps surrounding text' do
      html = helper.simple_format_with_links("Zobacz https://panel.kw.krakow.pl/przejscia/abc.\n\n#couplegoals")

      expect(html).to include('<a target="_blank" rel="noopener noreferrer" href="https://panel.kw.krakow.pl/przejscia/abc">')
      expect(html).to include('</a>.')
      expect(html).to include('#couplegoals')
    end

    it 'escapes HTML in user input' do
      html = helper.simple_format_with_links('<script>alert(1)</script> http://example.com')

      expect(html).not_to include('<script>')
      expect(html).to include('href="http://example.com"')
    end
  end
end
