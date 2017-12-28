class RegexpMatcher
  def ping(line)
    line.match(/^PING :(.*)$/)
  end

  def subs(line)
    regexp = /.*;display-name=(?<username>\w*).*login=(?<login>.*);m.*msg-id=(?<type>\w*);msg-param-months=(?<month>\w*).*;msg-param-sub-plan=(?<plan>\w*).* USERNOTICE #(?<channel>\w*)( :(?<message>.*))?/
    matcher(line, regexp)
  end

  def bits(line)
    regexp = /.*bits=(?<amount>\d*).*display-name=(?<username>\w*).* PRIVMSG #(?<channel>\w*)( :(?<message>.*)?)/
    matcher(line, regexp)
  end

  def subs_username(line)
    regexp = /.*;system-msg=(?<username>\w*).*/
    matcher(line, regexp)
  end

  def bits_username(line)
    regexp = /@(?<username>\w*).tmi.twitch.tv/
    matcher(line, regexp)
  end

  def command(line)
    regexp = /@badges=(?<badges>.*);.*;display-name=(?<username>.*);emotes=.*;mod=(?<mod>(1|0));.*subscriber=(?<subscriber>(1|0));.*@(?<username_backup>.*).tmi.twitch.tv PRIVMSG #(?<channel>.+) :(?<command>!\w+)( (?<options>.*))?/
    matcher(line, regexp)
  end

  def matcher(line, regexp)
    match = line.match(regexp)
    return unless match
    match.names.zip(match.captures).to_h
  end
end
