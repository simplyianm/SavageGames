package net.savagegames.savagegames

import java.util.concurrent.ArrayBlockingQueue
import org.bukkit.entity.Player
import java.util.HashMap
import org.bukkit.World
import org.bukkit.ChatColor

import org.bukkit.potion.PotionEffect
import org.bukkit.potion.PotionEffectType

import org.bukkit.event.player.PlayerLoginEvent
import org.bukkit.Location

##
# Router for a single game server.
#
class SingleGamePlayerRouter < PlayerRouter

  def current_game; @current_game; end

  def initialize(main:SavageGames)
    super main

    @current_game = Game(nil)
    @queue = ArrayBlockingQueue.new 10
  end

  def setup
    delete_old_worlds
    ensure_game_exists
  end

  def handle_game_end(game:Game):void
    if game.equals current_game
      @current_game = nil
      delete_old_worlds
      ensure_game_exists
    end
  end

  def route(player:Player)
    ensure_game_exists

    if current_game.phase.is_at_least GamePhases.Diaspora
      unless current_game.players.contains player.getName
        current_game.add_spectator player.getName
      end
    else
      route_to_lobby player
    end
  end

  def route_death(player:Player, game:Game)
    reset_player player
    player.kickPlayer ChatColor.GREEN.toString + 'You have been killed!'

#    game.add_spectator player
  end

  def handle_login(event:PlayerLoginEvent):void
    if current_game.phase.is_at_least GamePhases.Diaspora
      if current_game.players.contains event.getPlayer.getName
        current_game.cancel_task "logout_delay_#{event.getPlayer.getName}"
        return
      end
      event.setKickMessage ChatColor.YELLOW.toString + 'Sorry, tribute, a game is currently in progress. Come again later!'
      event.setResult PlayerLoginEvent.Result.KICK_OTHER
    end
  end

  ##
  # Deletes old worlds
  #
  def delete_old_worlds
    # Check for extraneous old worlds
    main.getServer.getWorlds.each do |w|
      world = World(w)
      if world.getName.startsWith '__sgame__'
        main.mv.getCore.getMVWorldManager.deleteWorld world.getName
      end
    end
  end

  ##
  # Routes a player to the lobby.
  #
  def route_to_lobby(player:Player)

    player.sendMessage ChatColor.GREEN.toString + 'Welcome to the SavageGames!'
    player.sendMessage ChatColor.GREEN.toString + 'Please choose a class with the command /class <class name>'
    player.sendMessage ChatColor.YELLOW.toString + 'Available classes: ' + main.classes.list_classes_available(player)

    reset_player player

    # Add to the game
    current_game.add_participant player.getName
    main.getServer.getScheduler.scheduleSyncDelayedTask main, TeleportTask.new(self, player, current_game.type.spawn), long(20)
  end

  ##
  # Resets a player to normal state.
  #
  def reset_player(player:Player)
    # Remove all potion effects
    player.getActivePotionEffects.each do |e|
      effect = PotionEffect(e)
      begin
        player.removePotionEffect effect.getType
      rescue Exception
        # Slacka!
      end
    end

    # Remove main inv
    inv = player.getInventory.getContents
    inv.length.times {|i|
      inv[i] = null
    }
    player.getInventory.setContents inv

    # Remove armor inv
    ainv = player.getInventory.getArmorContents
    ainv.length.times {|i|
      ainv[i] = null
    }
    player.getInventory.setArmorContents ainv

    player.updateInventory

    # Heal
    player.setHealth 20
    player.setFoodLevel 20

    # No exp
    player.setLevel 0
    player.setExp 0
  end

  ##
  # Ensures that a game exists.
  #
  def ensure_game_exists
    @current_game = main.games.get_any_game
    if @current_game == nil
      @current_game = main.games.create_game next_game_type
      @current_game.start
    end
  end

  ##
  # Hack for populating the 'random' queue.
  # Let's hope nobody finds out what map is going
  # to be next via the source code that's on Github.
  #
  def populate_queue()
    settings = HashMap.new
    settings.put 'capacity', Integer.valueOf(24)
    settings.put 'min_players', Integer.valueOf(4)

    @queue.add WorldGameType.new settings
    @queue.add WorldGameType.new settings
    @queue.add WorldGameType.new settings
    @queue.add WorldGameType.new settings
    @queue.add WorldGameType.new settings
    @queue.add WorldGameType.new settings
    @queue.add WorldGameType.new settings
    @queue.add WorldGameType.new settings
    @queue.add WorldGameType.new settings
    @queue.add WorldGameType.new settings
  end

  ##
  # Gets the next game type.
  #
  def next_game_type():GameType
    if @queue.size <= 0
      populate_queue
    end

    return GameType(@queue.poll)
  end

  def motd:String
    phase = current_game.phase
    if phase.equals GamePhases.Lobby
      return 'Waiting for players'
    end

    return 'Game in progress. Go to http://mcsg.co for servers.'
  end
end

class TeleportTask
  implements Runnable

  def initialize(router:SingleGamePlayerRouter, player:Player, loc:Location)
    @router = router
    @player = player
    @loc = loc
  end

  def run:void
    @player.teleport @loc
    @router.reset_player @player
  end
end
