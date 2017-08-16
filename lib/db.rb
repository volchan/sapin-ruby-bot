require 'active_record'

ActiveRecord::Base.establish_connection(
  adapter: 'postgresql',
  host: ENV['DB_HOST'],
  database: ENV['DB_NAME'],
  username: ENV['DB_USERNAME'],
  password: ENV['DB_PASSWORD']
)

class User < ActiveRecord::Base
  has_many :bots, dependent: :destroy
end

class Bot < ActiveRecord::Base
  belongs_to :user
  has_many :boss_games, dependent: :destroy
  before_create :generate_token

  private

  def generate_token
    self.token = loop do
      random_token = SecureRandom.urlsafe_base64(nil, false)
      break random_token unless Bot.exists?(token: random_token)
    end
  end
end

class BossGame < ActiveRecord::Base
  belongs_to :bot
end
