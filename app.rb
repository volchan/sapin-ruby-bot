require_relative 'lib/twitch_bot'
require_relative 'lib/game'
require_relative 'lib/db'


bot = TwitchBot.new(channels: %w[monsieursapin])

p bot.run
p bot.running
