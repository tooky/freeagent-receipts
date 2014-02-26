require 'sinatra/base'
require 'net/http'
require 'json'

# based on https://gist.github.com/dragossh/9f5fa66581e24dc9c85f

begin
  require 'dotenv'
  Dotenv.load
rescue LoadError
  # continue assuming env is set manually
end

class App < Sinatra::Base
  FA_URI = URI('https://api.freeagent.com')
  CLIENT_ID     = ENV['CLIENT_ID']
  CLIENT_SECRET = ENV['CLIENT_SECRET']
  USE_SSL = true

  def initialize
    super
    @@auth_token = nil
    @@access_token = nil
    @@refresh_token = nil
  end

  # Show current state
  get '/' do
    if @@auth_token.nil? && @@access_token.nil? && @refresh_code.nil?
      # Link to the authorization request, also needs a redirect_uri if that is not set in the dev dashboard
      "<a href=\"#{FA_URI.to_s}/v2/approve_app?response_type=code&client_id=#{CLIENT_ID}\">Authorize</a>"
    elsif @@auth_token && !@@access_token && !@@refresh_token
      "Auth token: #{@@auth_token}<br />" <<
      '<a href="/exchange_token">Exchange token for access and refresh tokens</a>'
    else
      "Access token: #{@@access_token}<br />" <<
      "Refresh token: #{@@refresh_token}<br />" <<
      '<a href="/reset">Reset codes</a>'
    end
  end

  # Step 1: Fetch Authorization token afte the user clicked "Authorize"
  get '/auth_endpoint' do
    code = params[:code]
    error = params[:error]

    return params[:error_description] if error

    if code
      @@auth_token = code
      redirect to('/')
    end
  end

  # Step 2: Exchange tokens once we have the authorization code
  get '/exchange_token' do
    if @@auth_token
      http = Net::HTTP.new(FA_URI.hostname, FA_URI.port)
      http.use_ssl = USE_SSL

      req = Net::HTTP::Post.new('/v2/token_endpoint')
      req['Content-Type'] = 'application/x-www-form-urlencoded;charset=UTF-8'
      req.body = "grant_type=authorization_code&code=" << @@auth_token # also needs a redirect_uri if that is not set in the dev dashboard
      req.basic_auth CLIENT_ID, CLIENT_SECRET

      res = http.request(req)

      if res.kind_of?(Net::HTTPOK)
        json = JSON.parse(res.body)
        @@access_token = json['access_token']
        @@refresh_token = json['refresh_token']
        redirect to('/')
      else
        'Failed to get access and refresh tokens: ' << res.body
      end
    else
      redirect to('/')
    end
  end

  get '/reset' do
    @@auth_token = nil
    @@access_token = nil
    @@refresh_token = nil
    redirect to ('/')
  end
end

App.run! :port => 4567
