# frozen_string_literal: true

require 'eventmachine'

# Object that handles events coming from the Rust server
class RustEvents
  def initialize(connection_factory, helpers)
    EM.run do
      @ws = connection_factory.wrcon_connection
      @helpers = helpers
      open
      message
      close
      error
    end
  end
  def open
    @ws.on :open do
      puts 'Connected to Rust WebSocket.'
    end
  end
  def message
    @ws.on :message do |event|
      parse_rust_message(event.data)
      puts event.data
    end
  end
  def close
    @ws.on :close do |code, reason|
      puts "WebSocket closed: #{code} #{reason}"
    end
  end
  def error
    @ws.on :error do |event|
      @helpers.debug_notification("**Rust Server** - #{event.message}")
    end
  end
  def parse_rust_message(message)
    message_parsed = JSON.parse(message)['Message']
    if message_parsed.include?('has entered the game')
      rust_channel = @helpers.get_discord_channel('rust-server')
      parsed_message = message_parsed.gsub!(/\[.*\]/, '')
      if rust_channel.history(1).first.content != parsed_message
        rust_channel.send_message(parsed_message)
        normalized = parsed_message.sub('entered the game', 'joined')
        rust_msg = "{Message: 'say #{normalized}', Type: 'Command'}"
        @ws.send(rust_msg)
      end
    end
  end
end
