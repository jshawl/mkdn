require 'sinatra'
require 'dropbox_sdk'
require './env' if File.exists? 'env.rb'

enable :sessions
set :session_secret, DB_SESSION_SECRET

get '/' do
  session['access_token'] ||= ''
  if session['access_token'] != ''
    client = get_dropbox_client
    @client = client.account_info['display_name']
    path = params[:path] || '/'
    begin
      entry = get_dropbox_client.metadata(path)
    rescue DropboxAuthError => e
      session.delete(:access_token)  # An auth error means the access token is probably bad
      logger.info "Dropbox auth error: #{e}"
    rescue DropboxError => e
      if e.http_response.code == '404'
      else
	logger.info "Dropbox API error: #{e}"
      end
    end

    if entry['is_dir']
      @files = entry['contents']
    else
      render_file(client, entry)
    end
  end
  erb :index
end

def get_auth
  redirect_uri = DB_CALLBACK
  flow = DropboxOAuth2Flow.new( DB_APP_KEY, DB_APP_SECRET, redirect_uri, session, :dropbox_auth_csrf_token)
end

get '/login' do
  auth_url = get_auth.start
  redirect to auth_url
end

get '/logout' do
  session.delete(:access_token)
  redirect to '/'
end

def get_dropbox_client
  return DropboxClient.new(session[:access_token]) if session[:access_token]
end

get '/callback' do
  code = params[:code]
  access_token, user_id, url_state = get_auth.finish(params)
  session['access_token'] = access_token
  redirect to '/'
end

get '/:path' do
  @file = get_dropbox_client.media(params[:path])
  erb :show
end

helpers do
  include Rack::Utils
  alias_method :h, :escape_html
end