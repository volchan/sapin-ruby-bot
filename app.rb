require_relative 'lib/twitch_bot'
require_relative 'lib/game'
require_relative 'lib/db'

bot = TwitchBot.new(channels: Bot.pluck(:channel))

bot.update_channels
bot.run
