# frozen_string_literal: true

require 'eventmachine'
require './helpers/rust_helpers'

# Object that handles events coming from the Rust server
module RustEvents
  extend Discordrb::EventContainer
  extend DiscordHelpers
  extend RustHelpers

  ready do |event|
    # Prevent multiple instances by conditionally assigning to instance variable
    @rust_eventmachine ||= Thread.new do
      EM.run do
        @ws = Connections.wrcon_connection
        @server = event.bot.server(ENV['EGEEIO_SERVER'].to_i)
        on_open
        on_message
        on_close
        on_error
      end
    end
  end

  module_function

  def on_open
    @ws.on :open do
      puts 'Connected to Rust WebSocket.'
    end
  end

  def on_message
    @ws.on :message do |event|
      msg = process_message(event)
      next unless msg.is_a?(Hash)

      puts "RUST: #{msg}"

      if msg.key?('COMMAND') && !check_last_message(rust_channel(@server), msg['COMMAND'])
        @ws.send(msg['COMMAND'])
      elsif msg.key?('SERVER') && !check_last_message(rust_channel, msg['SERVER'])
        rust_channel(@server).send_message(rust_server_message(msg['SERVER']))
      end
    end
  end

  def on_close
    @ws.on :close do |code, reason|
      debug_notification(@server, "**Rust Server** - #{code} #{reason}")
    end
  end

  def on_error
    @ws.on :error do |event|
      debug_notification(@server, "**Rust Server** - #{event.message}")
    end
  end
end
