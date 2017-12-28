require 'active_record'
require 'yaml'

if File.exist?('config/application.yml')
  var_hashes = YAML.safe_load(File.read('config/application.yml'))
  var_hashes['development'].each do |key, value|
    ENV[key] = value
    p "#{key} = #{ENV[key]}"
  end
end

ActiveRecord::Base.establish_connection(
  adapter: 'postgresql',
  host: ENV['DB_HOST'], # comment to tests on localhost
  username: ENV['DB_USER'], # comment to tests on localhost
  password: ENV['DB_PASSWORD'], # comment to tests on localhost
  database: ENV['DB_NAME']
)

class User < ActiveRecord::Base
  has_many :bots, dependent: :destroy
end

class Bot < ActiveRecord::Base
  belongs_to :user
  has_one :boss, dependent: :destroy
  before_create :generate_token

  private

  def generate_token
    self.token = loop do
      random_token = SecureRandom.urlsafe_base64(nil, false)
      break random_token unless Bot.exists?(token: random_token)
    end
  end
end

class Boss < ActiveRecord::Base
  belongs_to :bot
end
