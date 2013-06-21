class CustomCommand
  def call
    puts "omg"
  end
end

Spring.register_command "custom", CustomCommand.new
