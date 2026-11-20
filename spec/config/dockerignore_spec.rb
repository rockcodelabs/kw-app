# frozen_string_literal: true

require 'rails_helper'

# Dockerfile.production runs `COPY . .`: the .dockerignore decides what ends up in the production image.
RSpec.describe '.dockerignore' do
  let(:patterns) do
    File.readlines(Rails.root.join('.dockerignore'), chomp: true).map(&:strip).reject { |l| l.empty? || l.start_with?('#') }
  end

  # Docker semantics: the last matching pattern wins, a leading `!` re-includes.
  def ignored?(path)
    patterns.reduce(false) do |ignored, pattern|
      negated = pattern.start_with?('!')
      glob = pattern.delete_prefix('!').delete_prefix('/').chomp('/')
      matches = File.fnmatch?(glob, path, File::FNM_PATHNAME | File::FNM_DOTMATCH | File::FNM_EXTGLOB) ||
                path.start_with?("#{glob}/")
      matches ? !negated : ignored
    end
  end

  %w[
    .git/HEAD .github/workflows/test.yml .agents/skills/x.md .kamal/secrets ansible/site.yml docs/NEW_PRODUCTION_PLAN.md
    spec/rails_helper.rb .env .env.backup config/master.key config/credentials/production.key node_modules/x/index.js
    .bundle/config tmp/cache/x log/production.log latest.dump cron_log.log .DS_Store app/.DS_Store
  ].each do |path|
    it "keeps #{path} out of the image" do
      expect(ignored?(path)).to be(true)
    end
  end

  %w[
    Gemfile Gemfile.lock Rakefile config.ru package.json yarn.lock babel.config.js postcss.config.js .browserslistrc
    .ruby-version app/models/db/user.rb bin/rails bin/docker-entrypoint bin/cron config/application.rb config/crontab
    config/credentials/production.yml.enc db/schema.rb lib/tasks/periodic.rake public/robots.txt log/.keep
    vendor/assets/javascripts/responsive-tables.js
  ].each do |path|
    it "keeps #{path} in the image" do
      expect(ignored?(path)).to be(false)
    end
  end
end
