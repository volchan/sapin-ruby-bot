require 'socket'
require 'logger'
require 'English'
require 'rest-client'
require 'json'
require 'uri'

Thread.abort_on_exception = true

class TwitchBot
  attr_reader :socket, :logger, :running
  def initialize(attr = {})
    @logger = logger || Logger.new(STDOUT)
    @running = false
    @socket = nil
    @name = ENV['TWITCH_BOT_NAME']
    @channels = attr[:channels]
    @twitch_token = ENV['TWITCH_TOKEN']
    @boss = nil
    @heroku_bot = []
    @running = false
    @connected_channels = []
  end

  def run
    p @channel_updater
    @running = true
    logger.info("Innitializing bot #{inspect}...")
    initialize_bot
    until @socket.eof?
      line = @socket.gets
      # logger.info("> #{line}")

      ping = line.match(/^PING :(.*)$/)
      match = line.match(/.*;display-name=(?<username>\w*);.*PRIVMSG #(?<channel>.+) :(?<message>.+)/)
      usernotice = line.match(/USERNOTICE/)
      bits = line.match(/.*bits=(?<amount>\d*).*display-name=(?<username>\w*).* PRIVMSG #(?<channel>\w*)( :(?<message>.*)?)/)
      message = match && match[:message]
      # user = match && match[:username]
      # channel = match && match[:channel]

      if ping
        send_to_twitch("PONG #{ping[1]}")
      elsif usernotice
        p @channel_updater.alive?
        sub_match = line.match(/.*;display-name=(?<username>\w*).*msg-id=(?<type>\w*);msg-param-months=(?<month>\w*).*;msg-param-sub-plan=(?<plan>\w*).* USERNOTICE #(?<channel>\w*)( :(?<message>.*))?/)
        logger.info("LINE => #{line}")
        username = sub_match[:username]
        username = line.match(/.*;system-msg=(?<username>\w*).*/) if username.empty?
        logger.info("SUB => username: #{username}, type: #{sub_match[:type]}, channel: #{sub_match[:channel]}, plan: #{sub_match[:plan]}, month: #{sub_match[:month]}, message: #{sub_match[:message] || 'nil'}")
        # @boss.new_event(sub: { username: sub_match[:username], plan: sub_match[:plan] }) if live_state?
        heroku_bot = find_bot(sub_match[:channel])
        if live_state?(sub_match[:channel])
          RestClient.patch(
            "#{ENV['HEROKU_DOMAIN']}/bosses/#{heroku_bot.boss.id}",
            token: heroku_bot.token,
            bot_id: heroku_bot.id,
            event: {
              event_type: 'sub',
              channel: sub_match[:channel],
              username: username,
              type: sub_match[:type],
              plan: sub_match[:plan],
              month: sub_match[:month],
              message: sub_match[:message] || 'nil'
            }
          )
        end
      elsif message =~ /!stop/
        stop!
      elsif message =~ /!start/
        start!
      elsif bits
        username = line.match(/@(?<username>\w*).tmi.twitch.tv/) if username.empty?
        logger.info("LINE => #{line}")
        logger.info("BITS => username: #{bits[:username]}, channel: #{bits[:channel]}, total: #{bits[:amount]}")
        # @boss.new_event(bits: { username: bits[:username], amount: bits[:amount] }) if live_state?
        heroku_bot = find_bot(bits[:channel])
        if live_state?(sub_match[:channel])
          RestClient.patch(
            "#{ENV['HEROKU_DOMAIN']}/bosses/#{heroku_bot.boss.id}",
            token: heroku_bot.token,
            bot_id: heroku_bot.id,
            event: {
              event_type: 'bits',
              channel: bits[:channel],
              username: bits[:username],
              amount: bits[:amount],
              message: bits[:message] || 'nil'
            }
          )
        end
      end
    end
    @running = false
  end

  def live_state?(channel)
    api_call = RestClient.get("https://api.twitch.tv/kraken/streams/#{channel}?client_id=#{ENV['TWITCH_CLIENT_ID']}")
    parsed_api_call = JSON.parse(api_call)
    stream = parsed_api_call['stream']
    return if stream.nil?
    stream_type = stream['stream_type']
    stream_type == 'live'
  end

  def find_bot(channel)
    Bot.find_by(channel: channel)
  end

  def send_to_twitch(message)
    logger.info("< #{message}")
    @socket.puts(message)
  end

  def send_to_twitch_chat(message)
    @socket.puts("PRIVMSG ##{@channel} :#{message}")
  end

  def start!
    send_to_twitch_chat('now starting FeelsAmazingMan')
    # @running = true
  end

  def stop!
    send_to_twitch_chat('See you soon FeelsBadMan')
    # @running = false
  end

  def update_channels
    @channel_updater = Thread.new do
      loop do
        sleep 30
        Bot.pluck(:channel).each do |channel|
          next if @connected_channels.include? channel
          send_to_twitch("JOIN ##{channel}")
          logger.info("connected to ##{channel}")
          @connected_channels << channel
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
      send_to_twitch("JOIN ##{channel}")
      logger.info("connected to ##{channel}")
      @connected_channels << channel
    end
    send_to_twitch('CAP REQ :twitch.tv/membership')
    send_to_twitch('CAP REQ :twitch.tv/commands')
    send_to_twitch('CAP REQ :twitch.tv/tags')
    # send_to_twitch_chat("Salut c'est moi #{@username} Kappa !")
  end
end
