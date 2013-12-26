module Spring
  class CommandWrapper
    attr_reader :command

    def initialize(command)
      @command = command
      @setup   = false
    end

    def description
      if command.respond_to?(:description)
        command.description
      elsif command.respond_to?(:exec_name)
        "Runs the #{command.exec_name} command"
      else
        "No description given."
      end
    end

    def fallback(name)
      if command.respond_to?(:fallback)
        command.fallback
      else
        %{exec "bundle", "exec", "#{name}", *ARGV}
      end
    end

    def setup?
      @setup
    end

    def setup
      if !setup? && command.respond_to?(:setup)
        command.setup
        @setup = true
        return true
      else
        @setup = true
        return false
      end
    end

    def call
      if command.respond_to?(:call)
        command.call
      else
        $0 = exec
        load exec
      end
    end

    def gem_name
      if command.respond_to?(:gem_name)
        command.gem_name
      else
        exec_name
      end
    end

    def exec_name
      command.exec_name
    end

    def exec
      Gem.bin_path(gem_name, exec_name)
    end

    def env(args)
      if command.respond_to?(:env)
        command.env(args)
      end
    end
  end
end
