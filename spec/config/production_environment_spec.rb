# frozen_string_literal: true

require 'rails_helper'
require 'json'
require 'open3'

# Boots the app in RAILS_ENV=production in a subprocess (the test process itself runs as `test`) and sends
# real Rack requests through the middleware stack. Guards the TLS/host settings that sit behind kamal-proxy
# (config/deploy.production.yml: ssl + forward_headers): kamal-proxy terminates TLS, probes /up over plain
# HTTP with an arbitrary Host header, and passes X-Forwarded-Proto to the app.
RSpec.describe 'Production environment behind kamal-proxy' do
  def self.probe_script
    <<~RUBY
      require File.expand_path('config/application', Dir.pwd)
      # Production credentials are not available here: stub them and mock Fog so that booting never touches OVH.
      Rails.application.credentials.define_singleton_method(:dig) { |*_keys| 'x' }
      require 'fog/openstack'
      Fog.mock!
      # A route that needs no view, assets or database, only writes the session cookie.
      Rails.application.routes.append do
        get '/__probe', to: proc { |env| env['rack.session']['probe'] = 1; [200, { 'Content-Type' => 'text/plain' }, ['ok']] }
      end
      Rails.application.initialize!
      require 'rack/mock'
      require 'json'
      app = Rails.application
      request = lambda do |url, headers = {}|
        # MockRequest sets no HTTP_HOST, which every real request carries and host authorization reads.
        response = Rack::MockRequest.new(app).get(url, { 'HTTP_HOST' => URI(url).authority }.merge(headers))
        { status: response.status, location: response['Location'], cookies: Array(response['Set-Cookie']).join("\\n") }
      rescue StandardError => e
        { status: 500, error: e.class.name }
      end
      https = { 'HTTP_X_FORWARDED_PROTO' => 'https' }
      puts '--RESULT--' + JSON.generate(
        log_level: Rails.logger.level,
        force_ssl: app.config.force_ssl,
        health_http_known_host: request.call('http://nowypanel.kw.krakow.pl/up'),
        health_http_container_host: request.call('http://3f2a9c1b7d10:3000/up'),
        page_http: request.call('http://nowypanel.kw.krakow.pl/__probe'),
        page_https: request.call('http://nowypanel.kw.krakow.pl/__probe', https),
        page_https_cutover_host: request.call('http://panel.kw.krakow.pl/__probe', https),
        page_https_foreign_host: request.call('http://evil.example.com/__probe', https)
      )
    RUBY
  end

  def self.boot_production
    env = {
      'RAILS_ENV' => 'production', 'RACK_ENV' => 'production', 'SECRET_KEY_BASE' => 'x' * 64,
      'DB_HOST' => 'localhost', 'POSTGRES_USER' => 'x', 'POSTGRES_PASSWORD' => 'x',
      'REDIS_URL_SIDEKIQ' => 'redis://localhost:6379/1', 'APPSIGNAL_ACTIVE' => 'false'
    }
    out, err, status = Open3.capture3(env, 'bundle', 'exec', 'ruby', '-', stdin_data: probe_script, chdir: Rails.root.to_s)
    raise "production boot failed:\n#{err}\n#{out}" unless status.success?

    JSON.parse(out[/--RESULT--(.*)/, 1], symbolize_names: true)
  end

  before(:all) { @result = self.class.boot_production }

  let(:result) { @result }

  it 'logs at info, not debug' do
    expect(result[:log_level]).to eq(Logger::INFO)
  end

  it 'forces SSL' do
    expect(result[:force_ssl]).to be(true)
  end

  it 'answers the kamal-proxy health check over plain HTTP, for any Host' do
    expect(result[:health_http_known_host][:status]).to eq(200)
    expect(result[:health_http_container_host][:status]).to eq(200)
  end

  it 'redirects other plain-HTTP requests to HTTPS' do
    expect(result[:page_http][:status]).to eq(301)
    expect(result[:page_http][:location]).to eq('https://nowypanel.kw.krakow.pl/__probe')
  end

  it 'serves HTTPS requests forwarded by the proxy without a redirect loop' do
    expect(result[:page_https][:status]).to eq(200)
  end

  it 'accepts the rehearsal host and the final host' do
    expect(result[:page_https][:status]).to eq(200)
    expect(result[:page_https_cutover_host][:status]).to eq(200)
  end

  it 'rejects any other Host header' do
    expect(result[:page_https_foreign_host][:status]).to eq(403)
  end

  it 'sets secure, HttpOnly, SameSite=Lax session cookies' do
    cookies = result[:page_https][:cookies]
    expect(cookies).to include('_kw_app_session')
    expect(cookies).to match(/secure/i).and match(/httponly/i).and match(/samesite=lax/i)
  end
end
