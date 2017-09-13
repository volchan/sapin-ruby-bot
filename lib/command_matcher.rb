class CommandMatcher
  def initialize(bot)
    @bot = bot
  end

  def dispatch(attr)
    broadcaster = attr['badges'].gsub(%r{\/\d,?}, ' ').split.include?('broadcaster')
    attr['username'].empty? ? username = attr['username_backup'] : username = attr['username']
    mod = attr['mod']
    subscriber = attr['subscriber']
    channel = attr['channel']
    command = attr['command']
    options = attr['options']

    if command =~ /!start/ && (broadcaster || mod == '1')
      start(channel)
    elsif command =~ /!hello/
      hello(channel, username)
    end
  end

  def start(channel)
    message = 'Now strating FeelsAmazingMan'
    reply_in_chat(channel, message)
  end

  def hello(channel, username)
    message = "Hi @#{username} VoHiYo"
    reply_in_chat(channel, message)
  end

  def reply_in_chat(channel, message)
    @bot.send_to_twitch_chat(channel: channel, message: message)
  end
end
