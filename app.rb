require 'rubygems'
require 'sinatra'
require 'curb'
require 'nokogiri'
require 'json'

require 'my_anime_list/anime'

# Sinatra settings.
set :sessions, true

helpers do
  include MyAnimeList::Rack::Auth
end

before do
  # Authenticate with MyAnimeList if we don't have a cookie string.
  authenticate unless session['cookie_string']
end

# Get an anime's details.
get '/anime/:id' do
  pass unless params[:id] =~ /^\d+$/

  content_type :json

  # FIXME This should catch any exceptions, such as 404 or network/HTTP errors.
  anime = MyAnimeList::Anime.scrape_anime(params[:id], session['cookie_string'])

  anime.to_json
end

# Edit an anime.
post 'anime/:id' do
end

# Get a user's anime list.
get '/anime' do
  content_type :json

  curl = Curl::Easy.new('http://myanimelist.net/panel.php?go=export')
  curl.cookies = session['cookie_string']
  curl.http_post(
    Curl::PostField.content('type', '1'),
    Curl::PostField.content('subexport', 'Export My List')
  )

  html_doc = Nokogiri::HTML(curl.body_str)
  xml_url = html_doc.at('div.goodresult a')['href']

  curl.url = xml_url
  curl.perform

  require 'zlib'
  require 'stringio'

  response = Zlib::GzipReader.new(StringIO.new(curl.body_str)).read
  xml_doc = Nokogiri::XML.parse(response)

  anime_list = xml_doc.search('anime').map do |anime_node|
    anime = MyAnimeList::Anime.new
    anime.id                = anime_node.at('series_animedb_id').text
    anime.title             = anime_node.at('series_title').text
    anime.type              = anime_node.at('series_type').text
    anime.episodes          = anime_node.at('series_episodes').text
    anime.watched_episodes  = anime_node.at('my_watched_episodes').text
    anime.score             = anime_node.at('my_score').text
    anime.watched_status    = anime_node.at('my_status').text

    anime
  end

  anime_list.to_json
end

# Search for anime.
get 'anime/search' do
end