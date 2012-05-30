package net.savagerealms.savagegames

import java.util.ArrayList
import java.util.Date
import java.util.HashMap

import org.bukkit.entity.Player
import org.bukkit.Bukkit
import org.bukkit.World

# Represents an active game.
class Game
  # Accessors
  def world; @world; end
  def mode; @mode; end
  def participants; @participants; end
  def players; @players; end
  def spectators; @spectators; end

  def type; @type; end

  # Initializes a game.
  def initialize(type:GameType)
    @type = type
    @world = world

    changeMode "waiting"

    @participants = ArrayList.new
    @players = ArrayList.new
    @spectators = ArrayList.new
  end

  ###################
  # WAITING
  ###################

  # Adds a participant to the game.
  def addParticipant(p:Player)
    @participants.add p unless isFull?
  end

  # Checks if the game is a full game.
  def isFull?
    @type.capacity <= @participants.size
  end

  ###################
  # STARTING
  ###################

  # Checks if the game can be started.
  def canStart
    if @participants.size < @type.minPlayers
      return false
    end

    return true
  end

  # Starts the game.
  def start
    unless canStart
      return false # Don't do this! Use canStart directly before starting.
    end

    changeMode "starting"

    @task = Bukkit.getScheduler.scheduleAsyncRepeatingTask SavageGames.i, \
      GameCountdown.new(self, 10), 0, 20

    return true
  end

  # Ends an in-progress countdown.
  def endCountdown
    Bukkit.getScheduler.cancelTask @task if @task != 0
  end

  ###################
  # INGAME
  ###################

  # Begins the ingame phase of the game.
  def beginIngame
    changeMode "ingame"
    endCountdown
    broadcast "May the games forever be in your favor!"
  end

  ###################
  # ENDGAME
  ###################

  # The endgame -- 2 contestants left!
  def beginEndgame
    changeMode "endgame"
    broadcast "Two contestants left!"
  end

  ###################
  # GENERAL
  ###################

  # Changes the mode of the game.
  def changeMode(mode:String)
    event = EventFactory.callGameModeChange self, mode
    @mode = event.mode
  end

  # Broadcasts a message to all participants of the game.
  def broadcast(message:String)
    @participants.each do |p|
      Player(p).sendMessage message # Mirah doesn't have generics yet.
    end
  end

end

# Game Countdown helper class.
class GameCountdown
  implements Runnable
  
  def initialize(game:Game, time:int)
    @game = game
    @time = time
  end

  def run
    if @time > 0
      @game.broadcast Integer.toString(@time) + " seconds left!"
    else
      @game.beginIngame
    end
    @time -= 1
  end
end
