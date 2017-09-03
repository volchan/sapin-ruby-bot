require 'socket'
require 'logger'
require 'English'

class TwitchBot
  attr_reader :socket, :logger, :running
  def initialize(attr = {})
    @logger = logger || Logger.new(STDOUT)
    @running = false
    @socket = nil
    @name = attr[:name]
    @channel = attr[:channel]
    @twitch_token = attr[:twitch_token]
    @boss = nil
  end

  def run
    unless heroku_bot = Bot.find_by_channel(@channel)
      heroku_bot = Bot.create(
        name: @name,
        channel: @channel,
        twitch_token: @twitch_token,
        user: User.first
      )
    end

    initialize_boss(heroku_bot)

    logger.info("Innitializing bot #{inspect}...")
    initialize_bot

    until @socket.eof?
      @running = true
      heroku_bot.update(running: @running)
      line = @socket.gets
      # logger.info("> #{line}")

      ping = line.match(/^PING :(.*)$/)
      match = line.match(/.*;display-name=(?<username>\w*);.*PRIVMSG #(?<channel>.+) :(?<message>.+)/)
      usernotice = line.match(/USERNOTICE/)
      bits = line.match(/.*bits=(?<amount>\d*).*display-name=(?<username>\w*).*/)
      message = match && match[:message]
      # user = match && match[:username]
      # channel = match && match[:channel]

      if ping
        send_to_twitch("PONG #{ping[1]}")
      elsif usernotice
        sub_match = line.match(/.*;display-name=(?<username>\w*).*msg-id=(?<type>\w*);msg-param-months=(?<month>\w*).*;msg-param-sub-plan=(?<plan>\w*).* USERNOTICE #(?<channel>\w*)( :(?<message>.*))?/)
        logger.info("LINE => #{line}")
        username = sub_match[:username]
        if username.empty?
          second_match = line.match(/.*;system-msg=(?<username>\w*).*/)
          username = second_match[:username]
        end
        logger.info("SUB => username: #{username}, type: #{sub_match[:type]}, plan: #{sub_match[:plan]}, month: #{sub_match[:month]}, message: #{sub_match[:message] || 'nil'}")
        @boss.new_event(sub: { username: sub_match[:username], plan: sub_match[:plan] }) if live_state?
      elsif message =~ /!stop/
        stop!
      elsif message =~ /!start/
        start!
      elsif bits
        logger.info("LINE => #{line}")
        logger.info("BITS => username: #{bits[:username]}, total: #{bits[:amount]}")
        @boss.new_event(bits: { username: bits[:username], amount: bits[:amount] }) if live_state?
      end
    end
    @running = false
    heroku_bot.update(running: @running)
  end

  def live_state?
    api_call = RestClient.get("https://api.twitch.tv/kraken/streams/#{@channel}?client_id=#{ENV['TWITCH_CLIENT_ID']}")
    parsed_api_call = JSON.parse(api_call)
    stream = parsed_api_call['stream']
    unless stream.nil?
      stream_type = stream['stream_type']
      stream_type == 'live'
    end
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

  def initialize_bot
    logger.info('Preparing to connect...')
    @socket = TCPSocket.new('irc.chat.twitch.tv', 6667)
    logger.info("connected to socket : #{@socket.inspect}")
    send_to_twitch("PASS #{@twitch_token}")
    send_to_twitch("NICK #{@name}")
    send_to_twitch("JOIN ##{@channel}")
    send_to_twitch('CAP REQ :twitch.tv/membership')
    send_to_twitch('CAP REQ :twitch.tv/commands')
    send_to_twitch('CAP REQ :twitch.tv/tags')
    logger.info("connected to ##{@channel}")
    # send_to_twitch_chat("Salut c'est moi #{@username} Kappa !")
  end

  def initialize_boss(heroku_bot)
    logger.info('initializing boss...')
    @boss = Game.new(@logger, self, heroku_bot)
    logger.info('boss initialized...')
    logger.info(@boss.name)
    logger.info(@boss.avatar)
    logger.info(@boss.shield)
    logger.info("#{@boss.current_hp}/#{@boss.max_hp}")
    logger.info(@boss.saved_at)
  end
end
