require 'socket'
require 'logger'
require 'English'
require 'rest-client'
require 'json'
require 'uri'

Thread.abort_on_exception = true

class TwitchBot
  attr_reader :logger
  def initialize(attr = {})
    @logger = logger || Logger.new(STDOUT)
    @socket = nil
    @name = ENV['TWITCH_BOT_NAME']
    @channels = attr[:channels]
    @twitch_token = ENV['TWITCH_TOKEN']
    @connected_channels = []
    @regexp_matcher = RegexpMatcher.new
    @command_matcher = CommandMatcher.new(self)
  end

  def run
    logger.info("Innitializing bot #{inspect}...")
    initialize_bot
    until @socket.eof?
      line = @socket.gets

      if ping = @regexp_matcher.ping(line)
        send_to_twitch("PONG #{ping[1]}")
      elsif sub_match = @regexp_matcher.subs(line)
        sub_match['username'].empty? ? username = @regexp_matcher.subs_username(line)['username'] : username = sub_match['username']
        username.empty? ? username = sub_match['login'] : username
        sub_match['gifted_to'] = @regexp_matcher.sub_gifted_to(line)['gifted_to'] if sub_match['type'] == 'subgift'
        logger.info("LINE => #{line}")
        logger.info("SUB => username: #{username}, type: #{sub_match['type']}, gifted_to: #{sub_match['gifted_to']}, channel: #{sub_match['channel']}, plan: #{sub_match['plan']}, month: #{sub_match['month']}, message: #{sub_match['message']}")
        event = {
          event_type: 'sub',
          channel: sub_match['channel'],
          username: username,
          gifted_to: sub_match['gifted_to'],
          type: sub_match['type'],
          plan: sub_match['plan'],
          month: sub_match['month'],
          message: sub_match['message']
        }
        send_to_heroku(event, sub_match['channel']) if live_state?(sub_match['channel'])
        logger.info('=' * 20)
      elsif bits_match = @regexp_matcher.bits(line)
        bits_match['username'].empty? ? username = @regexp_matcher.bits_username(line)['username'] : username = bits_match['username']
        logger.info("LINE => #{line}")
        logger.info("BITS => username: #{bits_match['username']}, channel: #{bits_match['channel']}, total: #{bits_match['amount']}, message: #{bits_match['message']}")
        event = {
          event_type: 'bits',
          channel: bits_match['channel'],
          username: bits_match['username'],
          amount: bits_match['amount'],
          message: bits_match['message']
        }
        send_to_heroku(event, bits_match['channel']) if live_state?(bits_match['channel'])
        logger.info('=' * 20)
      elsif command_match = @regexp_matcher.command(line)
        @command_matcher.dispatch(command_match)
      end
    end
  end

  def live_state?(channel)
    api_call = RestClient.get("https://api.twitch.tv/kraken/streams/#{channel}?client_id=#{ENV['TWITCH_CLIENT_ID']}")
    parsed_api_call = JSON.parse(api_call)
    stream = parsed_api_call['stream']
    logger.info("> live: #{stream ? true : false}")
    return if stream.nil?
    stream_type = stream['stream_type']
    stream_type == 'live'
  end

  def send_to_heroku(event, channel)
    heroku_bot = find_bot(channel)
    RestClient.patch(
      "#{ENV['HEROKU_DOMAIN']}/bosses/#{heroku_bot.boss.id}",
      token: heroku_bot.boss.token,
      event: event
    )
  end

  def find_bot(channel)
    Bot.find_by(channel: channel)
  end

  def send_to_twitch(message)
    logger.info("< #{message}")
    @socket.puts(message)
  end

  def send_to_twitch_chat(attr)
    @socket.puts("PRIVMSG ##{attr[:channel]} :#{attr[:message]}")
  end

  def update_channels
    @channel_updater = Thread.new do
      loop do
        sleep 60
        heroku_bots = Bot.pluck(:channel)
        heroku_bots.each do |channel|
          next if @connected_channels.include?(channel)
          connect_to_twitch_tchat(channel)
        end
        @connected_channels.each do |channel|
          next if heroku_bots.include?(channel)
          disconnect_from_twitch_tchat(channel)
        end
      end
    end
  end

  def initialize_bot
    logger.info('Preparing to connect...')
    @socket = TCPSocket.new('irc.chat.twitch.tv', 6667)
    logger.info("connected to socket : #{@socket.inspect}")
    send_to_twitch("PASS #{@twitch_token}")
    send_to_twitch("NICK #{@name}")
    @channels.each do |channel|
      connect_to_twitch_tchat(channel)
    end
    send_to_twitch('CAP REQ :twitch.tv/membership')
    send_to_twitch('CAP REQ :twitch.tv/commands')
    send_to_twitch('CAP REQ :twitch.tv/tags')
  end

  def connect_to_twitch_tchat(channel)
    send_to_twitch("JOIN ##{channel}")
    logger.info("connected to ##{channel}")
    @connected_channels << channel
  end

  def disconnect_from_twitch_tchat(channel)
    send_to_twitch("PART ##{channel}")
    logger.info("disconnected from ##{channel}")
    @connected_channels.delete(channel)
  end
end
