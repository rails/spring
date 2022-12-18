require 'expedite/command/boot'

module Expedite
  def self.command(cmd)
    klass = Object.const_get("::Expedite::Command::#{cmd.capitalize}")
    klass.new
  rescue
    nil
  end
end
