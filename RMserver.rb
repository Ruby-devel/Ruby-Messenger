require 'eventmachine'
require 'json'
require 'colorize'
require 'sqlite3'
require 'openssl'

module MessengerServer
  class Connection < EventMachine::Connection
    attr_reader :username

    def post_init
      @username = nil
      @chat_room = 'general'
      puts "New client connected"
      send_landing_page
    end

    def receive_data(data)
      message = data.chomp
      if @username.nil?
        handle_username(message)
      else
        handle_command(message)
      end
    end

    def unbind
      puts "#{@username} disconnected"
      MessengerServer.broadcast("#{@username} has left the chat room #{@chat_room}", @chat_room)
      MessengerServer.remove_client(@username)
    end

    def handle_username(username)
      if MessengerServer.username_exists?(username)
        send_prompt("Username already exists. Please log in or choose another.")
      else
        @username = username
        MessengerServer.add_client(@username, self)
        join_chat_room(@username, @chat_room)
        send_prompt("Welcome, #{@username}! Type 'help' for available commands.")
        MessengerServer.broadcast("#{@username} has joined the chat room #{@chat_room}", @chat_room)
      end
    end

    def handle_command(message)
      case message.downcase
      when 'help'
        send_help_message
      when 'list'
        list_users
      when 'search'
        send_prompt("Enter the username to search:")
        start_user_search
      when 'add friend'
        send_prompt("Enter the username to add as a friend:")
        start_add_friend
      when 'friends'
        list_friends
      when 'switch room'
        send_prompt("Enter the chat room to switch:")
        start_switch_chat_room
      when 'exit'
        close_connection
      else
        MessengerServer.handle_command(@username, message)
      end
    end

    def send_landing_page
      send_data("Server active".colorize(:green) + " " + MessengerServer.get_animation + "\n")
      send_data("Welcome to the Messenger Server!\n")
      send_prompt("Please enter your username:")
    end

    def send_help_message
      help_message = <<-HELP
  Available Commands:
  - help: Display this help message
  - list: List all users
  - search: Search for a user
  - add friend: Add a user as a friend
  - friends: List your friends
  - switch room: Switch chat room
  - exit: Leave the chat
    HELP
      send_data("#{help_message}\n")
      send_prompt("Type 'help' for available commands.")
    end

    def list_users
      users = MessengerServer.list_users(@username)
      send_data("Users in the chat:\n#{users.join(', ')}\n")
      send_prompt("Type 'help' for available commands.")
    end

    def start_user_search
      @searching_user = true
    end

    def handle_user_search(username)
      found_users = MessengerServer.search_users(username)
      if found_users.empty?
        send_prompt("No users found with the username '#{username}'. Type 'search' to try again.")
      else
        send_data("Users found: #{found_users.join(', ')}\n")
        send_prompt("Type 'add friend' to add a user as a friend.")
      end
      @searching_user = false
    end

    def start_add_friend
      @adding_friend = true
    end

    def handle_add_friend(username)
      if MessengerServer.add_friend(@username, username)
        send_prompt("#{username} added to your friends. Type 'friends' to see your friends.")
      else
        send_prompt("#{username} not found. Type 'search' to find a user.")
      end
      @adding_friend = false
    end

    def list_friends
      friends = MessengerServer.list_friends(@username)
      send_data("Your friends: #{friends.join(', ')}\n")
      send_prompt("Type 'help' for available commands.")
    end

    def start_switch_chat_room
      @switching_chat_room = true
    end

    def handle_switch_chat_room(chat_room)
      join_chat_room(@username, chat_room)
      send_prompt("Switched to chat room #{chat_room}. Type 'help' for available commands.")
      @switching_chat_room = false
    end

    def join_chat_room(username, chat_room)
      MessengerServer.join_chat_room(username, chat_room)
      MessengerServer.broadcast("#{username} has joined the chat room #{chat_room}", chat_room)
    end

    def send_prompt(prompt)
      send_data("#{prompt}\n> ")
    end
  end

  @clients = {}
  @chat_rooms = {}
  @friends = {}

  def self.start_server(port)
    EventMachine.run do
      EventMachine.start_server('0.0.0.0', port, Connection)
      puts "Server active".colorize(:green) + " " + get_animation
      puts "Messenger Server started on port #{port}"
      trap("INT") { EventMachine.stop }
    end
  end

  def self.add_client(username, connection)
    @clients[username] = connection
  end

  def self.remove_client(username)
    @clients.delete(username)
    leave_chat_rooms(username)
  end

  def self.leave_chat_rooms(username)
    @chat_rooms.each do |_, users|
      users.delete(username)
    end
  end

  def self.broadcast(message, chat_room)
    @clients.each { |_, connection| connection.send_prompt(message) } if @chat_rooms[chat_room]
  end

  def self.handle_command(username, message)
    broadcast("#{username}: #{message}", 'general')
  end

  def self.join_chat_room(username, chat_room)
    @chat_rooms[chat_room] ||= []
    @chat_rooms[chat_room] << username
  end

  def self.list_users(exclude_user)
    (@clients.keys - [exclude_user]).join(', ')
  end

  def self.search_users(username)
    @clients.keys.select { |user| user.include?(username) }
  end

  def self.add_friend(user, friend)
    if @clients.key?(friend)
      @friends[user] ||= []
      @friends[user] << friend
      true
    else
      false
    end
  end

  def self.list_friends(user)
    @friends[user] || []
  end

  def self.get_animation
    ['|', '/', '-', '\\'].cycle.take(10).map { |frame| frame.colorize(:green) }.join
  end

  def self.username_exists?(username)
    @clients.key?(username)
  end
end

port = 3333
MessengerServer.start_server(port)
