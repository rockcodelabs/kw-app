# frozen_string_literal: true

require 'rails_helper'

# Rails 6.1 changed `where.not(a: nil, b: nil)` from `a IS NOT NULL AND b IS NOT NULL` to
# `NOT (a IS NULL AND b IS NULL)`. Old production (Rails 5.2) runs the old meaning, and the statistics
# queries were written for it. On the restored prod data the Rails 7 meaning counted 63 ski routes without a
# length and 883 regular-climbing routes that the leaderboards deliberately exclude (A.4 #3 in
# docs/NEW_PRODUCTION_PLAN.md). Write such conditions as chained `where.not(a: nil).where.not(b: nil)`.
RSpec.describe 'where.not with several conditions' do
  # Splits at top-level commas (outside (), [], {}) and ignores commas inside string literals.
  def top_level_parts(text)
    parts = [+'']
    depth = 0
    quote = nil
    text.each_char do |char|
      if quote
        quote = nil if char == quote
      elsif char == "'" || char == '"'
        quote = char
      elsif '([{'.include?(char)
        depth += 1
      elsif ')]}'.include?(char)
        depth -= 1
      elsif char == ',' && depth.zero?
        parts << +''
        next
      end
      parts.last << char
    end
    parts.map(&:strip).reject(&:empty?)
  end

  def call_arguments(source, start)
    depth = 1
    index = start
    while depth.positive? && index < source.length
      depth += 1 if source[index] == '('
      depth -= 1 if source[index] == ')'
      index += 1
    end
    source[start...(index - 1)]
  end

  # `where.not('position @> array[?]', 'senior')` is one SQL condition with a bind value: fine.
  # `where.not(a: nil, b: nil)` and `where.not(table: { a: nil, b: nil })` are several conditions: not fine.
  def multiple_conditions?(arguments)
    parts = top_level_parts(arguments)
    return false if parts.empty? || parts.first.start_with?("'", '"')
    return true if parts.size > 1

    nested = parts.first[/\A[\w.]+:\s*\{(.*)\}\z/m, 1]
    nested ? top_level_parts(nested).size > 1 : false
  end

  let(:offenders) do
    Dir[Rails.root.join('{app,lib,config}/**/*.{rb,rake,erb,slim,haml}').to_s].sort.flat_map do |path|
      source = File.read(path)
      source.to_enum(:scan, /where\.not\(/).map { Regexp.last_match }.filter_map do |match|
        arguments = call_arguments(source, match.end(0))
        next unless multiple_conditions?(arguments)

        "#{path.delete_prefix("#{Rails.root}/")}:#{source[0...match.end(0)].count("\n") + 1} where.not(#{arguments.squish})"
      end
    end
  end

  it 'is not used with more than one condition anywhere in the app code' do
    expect(offenders).to be_empty, "chain where.not calls instead:\n#{offenders.join("\n")}"
  end

  describe 'the detector itself' do
    it 'flags several keys, a nested hash with several keys, and nothing else' do
      expect(multiple_conditions?('length: nil, difficulty: %w[a b]')).to be(true)
      expect(multiple_conditions?('mountain_routes: { id: nil, length: nil }')).to be(true)
      expect(multiple_conditions?('id: nil, length: nil, difficulty: EXCLUDED_DIFFICULTY')).to be(true)

      expect(multiple_conditions?('length: nil')).to be(false)
      expect(multiple_conditions?("'position @> array[?]', 'senior'")).to be(false)
      expect(multiple_conditions?("supplementary_courses: { paid_email: ['', nil] }")).to be(false)
      expect(multiple_conditions?('mountain_routes: { length: nil }')).to be(false)
    end
  end
end
