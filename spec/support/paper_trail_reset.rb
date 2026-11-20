# frozen_string_literal: true

# ApplicationController#set_paper_trail_whodunnit stores the signed-in user in PaperTrail.request,
# which is thread-local state that controller specs never clear (the production middleware does it
# between requests). Without this, a random order can leak a user id into an unrelated spec, e.g. the
# cron worker spec that asserts the label does not stay behind (`expected: nil, got: 57`).
RSpec.configure do |config|
  config.before(:each) { PaperTrail.request.whodunnit = nil }
end
