require_relative 'lib/twitch_bot'
require_relative 'lib/game'
require_relative 'lib/db'

bot = TwitchBot.new(
  twitch_token: ENV['TWITCH_TOKEN'],
  name: 'sapinbot',
  channel: 'monsieursapin'
)
bot.run
