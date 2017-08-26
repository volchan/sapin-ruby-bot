# boss base max hp : 1000,
# when defeated, next boss gain 200 max hp
# when boss max hp > 5000 goes back to 1000

# damages for prime/5$ subs = 500hp
# damages for 10$ subs = 1000hp
# damages for 25$ subs = 3000hp

# damages for 1bit = 1hp

# if current_boss == sub[:username] || bits[:username] damages becomes heals

# heal for prime/5$ subs = 500hp
# heal for 10$ subs = 1000hp
# heal for 25$ subs = 3000hp

# heal for 1bit = 1hp

# if current_hp == max_hp heals are going into a shield
require 'logger'
require 'socket'
require 'rest-client'
require 'json'

class Game
  attr_reader :name, :max_hp, :shield, :boss_image, :logger, :bot
  def initialize(logger, bot, heroku_bot)
    @heroku_bot = heroku_bot
    @boss = init_boss('no boss yet!')
    @bot = bot
    @logger = logger
    @name = (@boss && @boss.name) || nil
    @max_hp = (@boss && @boss.max_hp) || 0
    @current_hp = (@boss && @boss.current_hp) || 0
    @shield = (@boss && @boss.shield) || 0
    @avatar = (@boss && @boss.avatar) || nil
    @saved_at
  end

  def new_event(attr)
    check_boss
    if attr[:sub]
      subscriber = attr[:sub]
      sub_event(username: subscriber[:username], plan: subscriber[:plan])
    elsif attr[:bits]
      bits = attr[:bits]
      bits_event(username: bits[:username], amount: bits[:amount])
    end
  end

  private

  def check_boss
    return if @boss.nil?
    heroku_boss = BossGame.find_by(bot: @heroku_bot)
    if @saved_at != heroku_boss.saved_at
      @saved_at = heroku_boss
    end
  end

  def name!(name)
    @name = name
  end

  def add_timestamp
    @saved_at = Time.now
  end
  def update_current_hp
    add_timestamp
    action = 'update_current_hp'
    params = "&current_hp=#{@current_hp}"
    send_request(action, params)
  end

  def update_shield
    add_timestamp
    action = 'update_shield'
    params = "&shield=#{@shield}"
    send_request(action, params)
  end

  def update_boss
    add_timestamp
    action = 'update_boss'
    params = "&name=#{@name}&max_hp=#{@max_hp}&current_hp=#{@current_hp}&shield=#{@shield}&avatar=#{@avatar}"
    send_request(action, params)
  end

  def create_boss
    add_timestamp
    action = 'create_boss'
    params = "&name=#{@name}&max_hp=#{@max_hp}&current_hp=#{@current_hp}&shield=#{@shield}&avatar=#{@avatar}"
    request_url = "https://volchan-web-twitch-boss-stagin.herokuapp.com/#{action}/?token=#{@heroku_bot.token}&bot_id=#{@heroku_bot.id}&saved_at=#{@saved_at}#{params}"
    RestClient.get(request_url)
  end

  def send_request(action, request_params)
    request_url = "https://volchan-web-twitch-boss-stagin.herokuapp.com/#{action}/#{@boss.id}/?token=#{@heroku_bot.token}&bot_id=#{@heroku_bot.id}&saved_at=#{@saved_at}#{request_params}"
    RestClient.get(request_url)
  end

  def find_avatar(name)
    api_call = RestClient.get("https://api.twitch.tv/kraken/channels/#{name}?client_id=#{ENV['TWITCH_CLIENT_ID']}")
    parsed_api_call = JSON.parse(api_call)
    parsed_api_call['logo']
  end

  def boss_avatar!(name)
    @avatar = find_avatar(name)
  end

  def reset_hp
    if @max_hp.zero?
      @max_hp = 1000
      @current_hp = @max_hp
    elsif @max_hp >= 1000 && @max_hp <= 4800
      @max_hp += 200
      @current_hp = @max_hp
    elsif @max_hp >= 5000
      @max_hp = 1000
      @current_hp = @max_hp
    end
  end

  def new_boss(name)
    logger.info("BOSS_GAME: #{@name} à était vaincu !")
    name!(name)
    reset_hp
    boss_avatar!(name)
    update_boss
    logger.info("BOSS_GAME: #{@name} est le nouveau boss !")
  end

  def init_boss(name)
    name!(name)
    @current_hp = 0
    @max_hp = 0
    @shield = 0
    @avatar = nil
    create_boss
    @boss = BossGame.last
  end

  def sub_damage_or_heal(plan)
    case plan
    when 'Prime' then 500
    when '1000' then 500
    when '2000' then 1000
    when '3000' then 3000
    end
  end

  def attack_shield(damages, username)
    previous_shield = @shield
    @shield -= damages
    logger.info("BOSS_GAME: #{username} inflige #{damages} points de dégâts au bouclier de #{@name} !")
    if @shield <= 0
      @shield = 0
      logger.info("BOSS_GAME: #{username} à détruit le bouclier de #{@name} !")
    end
    update_shield
    previous_shield
  end

  def add_shield(amount)
    @shield += amount if amount > 0
    logger.info("BOSS_GAME: #{@name} à ajouté #{amount} points à son bouclier ! #{@shield} pts")
    update_shield
  end

  def attack_boss(amount, username)
    damages = amount
    logger.info("BOSS_GAME: #{username} attaque #{@name} avec une puissance de #{damages} !")
    damages -= attack_shield(damages, username) if @shield > 0
    if damages > 0
      @current_hp -= damages
      logger.info("BOSS_GAME: #{username} inflige #{damages} points de dégâts à #{@name} ! #{@current_hp}/#{@max_hp}")
    else
      logger.info("BOSS_GAME: l'attaque de #{username} n'était pas assez puissante pour faire de dégâts à #{@name} ! #{@current_hp}/#{@max_hp}")
    end
    update_current_hp
  end

  def heal_boss(amount)
    heal = amount
    if @current_hp < @max_hp
      hp_to_heal = @max_hp - @current_hp
      if hp_to_heal <= heal
        @current_hp += hp_to_heal
        logger.info("BOSS_GAME: #{@name} c'est soigné pour #{hp_to_heal} hp ! #{@current_hp}/#{@max_hp}")
        shield_amount = (heal - hp_to_heal)
        update_current_hp
        add_shield(shield_amount)
        update_shield
      else
        @current_hp += heal
        logger.info("BOSS_GAME: #{@name} c'est soigné pour #{heal} hp ! #{@current_hp}/#{@max_hp}")
      end
    else
      add_shield(amount)
      update_shield
    end
  end

  def sub_event(attr)
    if @name.nil?
      init_boss(attr[:username])
    elsif attr[:username] == @name
      heal_boss(sub_damage_or_heal(attr[:plan]).to_i)
    else
      attack_boss(sub_damage_or_heal(attr[:plan]).to_i, attr[:username])
      new_boss(attr[:username]) if @current_hp <= 0
    end
  end

  def bits_event(attr)
    if @name.nil?
      init_boss(attr[:username])
    elsif attr[:username] == @name
      heal_boss(attr[:amount].to_i)
    else
      attack_boss(attr[:amount].to_i, attr[:username])
      new_boss(attr[:username]) if @current_hp <= 0
    end
  end
end
