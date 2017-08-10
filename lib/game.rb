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
    @boss = BossGame.find_by(bot: heroku_bot) || nil
    @bot = bot
    @logger = logger
    @name = (@boss && @boss.name) || nil
    @max_hp = (@boss && @boss.max_hp) || 0
    @current_hp = (@boss && @boss.current_hp) || 0
    @shield = (@boss && @boss.shield) || 0
    @avatar = (@boss && @boss.avatar) || nil
  end

  def new_event(attr)
    if attr[:sub]
      subscriber = attr[:sub]
      sub_event(username: subscriber[:username], plan: subscriber[:plan])
    elsif attr[:bits]
      bits = attr[:bits]
      bits_event(username: bits[:username], amount: bits[:amount])
    end
  end

  private

  def name!(name)
    @name = name
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
    # @bot.send_to_twitch_chat("#{@name} à était vaincu !")
    name!(name)
    reset_hp
    boss_avatar!(name)
    @boss.update(
      bot: @heroku_bot,
      name: @name,
      max_hp: @max_hp,
      current_hp: @current_hp,
      shield: @shield,
      avatar: @avatar
    )
    logger.info("BOSS_GAME: #{@name} est le nouveau boss !")
    # @bot.send_to_twitch_chat("#{@name} est le nouveau boss !")
  end

  def init_boss(name)
    name!(name)
    reset_hp
    boss_avatar!(name)
    @boss = BossGame.create(
      bot: @heroku_bot,
      name: @name,
      max_hp: @max_hp,
      current_hp: @current_hp,
      shield: @shield,
      avatar: @avatar
    )
    logger.info("BOSS_GAME: #{@name} est le nouveau boss !")
    # @bot.send_to_twitch_chat("#{@name} est le nouveau boss !")
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
    # @bot.send_to_twitch_chat("#{username} inflige #{damages} points de dégâts au bouclier de #{@name} !")
    if @shield <= 0
      @shield = 0
      logger.info("BOSS_GAME: #{username} à détruit le bouclier de #{@name} !")
      # @bot.send_to_twitch_chat("#{username} à détruit le bouclier de #{@name} !")
    end
    @boss.update(shield: @shield)
    previous_shield
  end

  def add_shield(amount)
    @shield += amount if amount > 0
    logger.info("BOSS_GAME: #{@name} à ajouté #{amount} points à son bouclier ! #{@shield} pts")
    @boss.update(shield: @shield)
    # @bot.send_to_twitch_chat("#{@name} à ajouté #{amount} points à son bouclier ! #{@shield} pts")
  end

  def attack_boss(amount, username)
    damages = amount
    logger.info("BOSS_GAME: #{username} attaque #{@name} avec une puissance de #{damages} !")
    # @bot.send_to_twitch_chat("#{username} attaque #{@name} avec une puissance de #{damages} !")
    damages -= attack_shield(damages, username) if @shield > 0
    if damages > 0
      @current_hp -= damages
      logger.info("BOSS_GAME: #{username} inflige #{damages} points de dégâts à #{@name} ! #{@current_hp}/#{@max_hp}")
      # @bot.send_to_twitch_chat("#{username} inflige #{damages} points de dégâts à #{@name} ! #{@current_hp}/#{@max_hp}")
    else
      logger.info("BOSS_GAME: l'attaque de #{username} n'était pas assez puissante pour faire de dégâts à #{@name} ! #{@current_hp}/#{@max_hp}")
      # @bot.send_to_twitch_chat("l'attaque de #{username} n'était pas assez puissante pour faire de dégâts à #{@name} ! #{@current_hp}/#{@max_hp}")
    end
    @boss.update(current_hp: @current_hp)
  end

  def heal_boss(amount)
    heal = amount
    if @current_hp < @max_hp
      hp_to_heal = @max_hp - @current_hp
      if hp_to_heal <= heal
        @current_hp += hp_to_heal
        logger.info("BOSS_GAME: #{@name} c'est soigné pour #{hp_to_heal} hp ! #{@current_hp}/#{@max_hp}")
        # @bot.send_to_twitch_chat("#{@name} c'est soigné pour #{hp_to_heal} hp ! #{@current_hp}/#{@max_hp}")
        shield_amount = (heal - hp_to_heal)
        add_shield(shield_amount)
      else
        @current_hp += heal
        logger.info("BOSS_GAME: #{@name} c'est soigné pour #{heal} hp ! #{@current_hp}/#{@max_hp}")
        # @bot.send_to_twitch_chat("#{@name} c'est soigné pour #{heal} hp ! #{@current_hp}/#{@max_hp}")
      end
    else
      add_shield(amount)
    end
    @boss.update(current_hp: @current_hp)
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
