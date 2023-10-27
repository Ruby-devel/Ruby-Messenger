require 'socket'
require 'colorize'

class MessengerClient
  def initialize(server_host, server_port)
    @server_host = server_host
    @server_port = server_port
    @username = nil
    @socket = TCPSocket.new(server_host, server_port)
    puts "Connected to the server at #{server_host}:#{server_port}".colorize(:green)
    listen_to_server
    send_user_data
    handle_user_input
  end

  def listen_to_server
    Thread.new do
      loop do
        message = @socket.gets.chomp
        puts message
        print '> '
      end
    end
  end

  def send_user_data
    loop do
      print '> '
      user_input = gets.chomp
      @socket.puts(user_input)
    end
  end

  def handle_user_input
    Thread.new do
      loop do
        user_input = gets.chomp
        @socket.puts(user_input)
      end
    end
  end
end

server_host = 'localhost'
server_port = 3333
MessengerClient.new(server_host, server_port)
