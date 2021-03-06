package net.savagegames.savagegames

import java.util.ArrayList
import java.util.Date
import java.util.HashMap

import org.bukkit.ChatColor
import org.bukkit.entity.Player
import org.bukkit.Bukkit
import org.bukkit.World

# Represents an active game.
class Game
  # Accessors
  def phase; @phase; end
  def phase=(phase:GamePhase); @phase = phase; end

  def report; @report; end
  def report=(report:GameReport); @report = report; end

  def players; @players; end
  def spectators; @spectators; end

  def type; @type; end
  
  def participants
    list = ArrayList.new(players)
    list.addAll spectators
    return list
  end

  ##
  # Initializes a game.
  #
  def initialize(type:GameType)
    @type = type
    @tasks = HashMap.new

    @players = ArrayList.new
    @spectators = ArrayList.new
  end

  ##
  # Starts the game.
  #
  def start:void
    @phase = GamePhases.Lobby
    @phase.begin self
  end

  ##
  # Removes a player from the game.
  #
  # Just from the list.
  #
  def remove_player(p:String):void
    @players.remove p
  end

  ##
  # Adds a participant to the game.
  #
  def add_participant(p:String):boolean
    unless is_full?
      players.add p
      return true
    end
    return false 
  end

  ##
  # Adds a spectator to the game.
  #
  def add_spectator(player:String):void
    if players.contains player
      players.remove player
    end

    @spectators.add player
  end

  ##
  # Checks if the game is a full game.
  #
  def is_full?
    @type.capacity <= @players.size
  end

  ##
  # Moves on to the next phase of the game.
  #
  def next_phase:void
    phase.end self
    nextt = phase.next

    if nextt != nil
      @phase = nextt
      nextt.begin self
    else
      end_game
    end
  end

  ##
  # Ends the game.
  #
  def end_game:void
    SavageGames.i.games.end_game self
  end

  ##
  # Broadcasts a message to all participants of the game.
  #
  def broadcast(message:String)
    participants.each do |p|
      pl = Bukkit.getPlayer String(p)
      if pl == nil
        next
      end
      pl.sendMessage message
    end
  end

  ##
  # Broadcasts a message only to people who have chosen a class.
  #
  def broadcast_to_players(message:String)
    participants.each do |p|
      pl = Bukkit.getPlayer String(p)
      if pl == nil
        next
      end
      clazz = SavageGames.i.classes.get_class_of_player pl
      unless clazz == nil
        pl.sendMessage message
      end
    end
  end

  ##
  # Handles when a player leaves the game.
  #
  def handle_leave(player:String):void
    unless phase.is_at_least GamePhases.Diaspora
      return
    end

    delay = GameLogoutDelay.new player

    start_delayed_task "logout_delay_#{player}", delay, 400 # 20 secs
  end

  ##
  # Checks for game progression
  #
  def check_progression:void
    next_phase if phase.should_progress?(self)
  end

  ###################
  # TASKS
  ###################

  ##
  # Starts a new repeating task.
  #
  def start_repeating_task(name:String, task:GameTask, delay:long, interval:long):void
    task.game = self
    task_id = Bukkit.getScheduler.scheduleSyncRepeatingTask SavageGames.i, task, delay, interval
    
    current = get_task name
    unless current < 0
      return
    end

    @tasks.put name, Integer.valueOf(task_id)
  end

  ##
  # Starts a new delayed task.
  #
  def start_delayed_task(name:String, task:GameTask, delay:long):void
    task.game = self
    task_id = Bukkit.getScheduler.scheduleSyncDelayedTask SavageGames.i, task, delay
    
    current = get_task name
    unless current < 0 and Bukkit.getScheduler.isQueued current
      return
    end

    @tasks.put name, Integer.valueOf(task_id)
  end

  ##
  # Cancels a task.
  #
  def cancel_task(name:String):void
    task = @tasks.get name

    current = get_task name
    unless current >= 0
      return
    end

    @tasks.remove name

    Bukkit.getScheduler.cancelTask current
  end

  ##
  # Gets a task.
  #
  private
  def get_task(name:String)
    task = @tasks.get name
    if task == nil
      return -1
    end

    unless task.kind_of? Integer
      return -1
    end

    return Integer(task).intValue
  end
end
