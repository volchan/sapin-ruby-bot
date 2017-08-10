require 'active_record'

ActiveRecord::Base.establish_connection(
  adapter:  'postgresql',
  host:     ENV['DB_HOST'],
  database: ENV['DB_NAME'],
  username: ENV['DB_USERNAME'],
  password: ENV['DB_PASSWORD']
)

class User < ActiveRecord::Base
  has_many :bots
end

class Bot < ActiveRecord::Base
  belongs_to :user
  has_many :boss_games, dependent: :destroy
end

class BossGame < ActiveRecord::Base
  belongs_to :bot
end
