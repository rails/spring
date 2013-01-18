class CustomCommand
  def call(args)
    puts "omg"
  end
end

Spring.register_command "custom", CustomCommand.new
