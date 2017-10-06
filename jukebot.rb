require 'dotenv'
Dotenv.load
require 'slack-ruby-bot'
require 'pry'

require_relative 'commands/what_is_playing'

require_relative 'includes/bot_regex'
require_relative 'includes/string_monkeypatch'

require_relative 'services/sonos_service'
require_relative 'services/spotify_service'

class JukeBot < SlackRubyBot::Bot
  def self.api
    @api ||= JukeBotService::Sonos.new
  end

  def self.spotify
    @spotify ||= JukeBotService::Spotify.new
  end

  find_music_regex = /find ?(?<digit>\d+)? music (?<query>.*)/i
  match BotRegex.new(find_music_regex) do |client, data, match|
    tracks = spotify.find_tracks(query: match[:query], limit: match[:digit])
    artist_array = []
    tracks.each do |track|
      artists = track.artists.map(&:name).join(',')
      name = track.name
      album = track.album.name
      artist_array << { artists: artists, name: name, album: album }
    end
    response = "I found the following #{artist_array.length} songs."
    artist_array.each_with_index do |artist, idx|
      response += "#{idx + 1}: #{artist[:name]} by #{artist[:artists]} on #{artist[:album]}. "
    end
    client.say(text: response, channel: data.channel)
  end

  play_regex = /play (?<play>.*)/i
  match BotRegex.new(play_regex) do |client, data, match|
    play_string = match[:play]
    if play_string.number?
      song_index = match[:play].to_i - 1
      api.spotify_play(track: spotify.last_search[song_index].uri)
      preview_image = spotify.last_search[song_index].album.images.first['url']
      response = "Alright, I'm now playing your request. #{preview_image}"
    else
      track = spotify.find_tracks(query: match[:play], limit: 1).first
      response = "Sorry couldn't find anything like that" && break unless track
      api.spotify_play(track: track.uri)
      response = "Alright, playing #{track.name}. "
      response += track.album.images.first['url']
    end
    client.say(text: response, channel: data.channel)
  end

  next_regex = /next (?<play>.*)/i
  match BotRegex.new(next_regex) do |client, data, match|
    play_string = match[:play]
    if play_string.number?
      song_index = match[:play].to_i - 1
      api.spotify_play(track: spotify.last_search[song_index].uri, when: 'next')
      preview_image = spotify.last_search[song_index].album.images.first['url']
      response = "Alright, I'm gonna play this next. #{preview_image}"
    else
      response = "Sorry, I couldn't figure out what to play next"
    end
    client.say(text: response, channel: data.channel)
  end

  queue_regex = /queue (?<play>.*)/i
  match BotRegex.new(queue_regex) do |client, data, match|
    play_string = match[:play]
    if play_string.number?
      song_index = match[:play].to_i - 1
      api.spotify_play(track: spotify.last_search[song_index].uri, when: queue)
      response = "Alright, I queued up #{spotify.last_search[song_index].name}"
    else
      response = "Sorry, I couldn't figure out what to queue up"
    end
    client.say(text: response, channel: data.channel)
  end

  volume_regex = /volume (?<volume>.*)/i
  match BotRegex.new(volume_regex) do |client, data, match|
    volume = match[:volume]
    if volume.number?
      api.change_volume(volume)
      response = "Set the volume to #{volume} :mega:"
    else
      response = "How am I supposed to chage the volume to #{volume}?"
    end
    client.say(text: response, channel: data.channel)
  end

  change_room_regex = /change\sroom\s(?:to )?(?<room>.*)$/i
  match BotRegex.new(change_room_regex) do |client, data, match|
    if api.change_room(match[:room])
      response = "Ok, room set to #{match[:room]}."
    else
      response = "Sorry, it doesn't look like that room exists."
      response += "Try #{api.rooms.join(', ')}"
    end
    client.say(text: response, channel: data.channel)
  end

  say_regex = /say\s(?<words>.*)$/i
  match BotRegex.new(say_regex) do |_client, _data, match|
    api.say(text: match[:words])
  end

  command 'pause' do |client, data, _match|
    api.pause
    response = 'Paused, partner. Say resume to start it up again.'
    client.say(text: response, channel: data.channel)
  end

  command 'resume' do |client, data, _match|
    api.play
    response = 'Here we go!'
    client.say(text: response, channel: data.channel)
  end

  command 'mute' do |client, data, _match|
    api.groupMute
    response = 'muted'
    client.say(text: response, channel: data.channel)
  end

  command 'unmute' do |client, data, _match|
    api.groupUnmute
    response = 'unmuted'
    client.say(text: response, channel: data.channel)
  end

  command 'rooms' do |client, data, _match|
    response = "Current rooms available for control are #{api.rooms}"
    client.say(text: response, channel: data.channel)
  end
end

JukeBot.run
