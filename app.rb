require_relative 'lib/regexp_matcher'
require_relative 'lib/command_matcher'
require_relative 'lib/twitch_bot'
require_relative 'lib/db'

bot = TwitchBot.new(channels: Bot.pluck(:channel))

bot.update_channels
bot.run
