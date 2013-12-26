require 'set'

module Spring
  module Client
    class Binstub < Command
      SHEBANG = /\#\!.*\n/

      LOADER = <<CODE
begin
  load File.expand_path("../spring", __FILE__)
rescue LoadError
end
CODE

      class Item
        attr_reader :command, :existing

        def initialize(command)
          @command = command

          if command.binstub.exist?
            @existing = command.binstub.read
          end
        end

        def status(text, stream = $stdout)
          stream.puts "* #{command.binstub_name}: #{text}"
        end

        def add
          if existing
            if existing =~ /load .*spring/
              status "spring already present"
            else
              head, shebang, tail = existing.partition(SHEBANG)

              if shebang.include?("ruby")
                File.write(command.binstub.to_s, "#{head}#{shebang}#{LOADER}#{tail}")
                status "spring inserted"
              else
                status "doesn't appear to be ruby, so cannot use spring", $stderr
                exit 1
              end
            end
          else
            File.write(
              command.binstub.to_s,
              "#!/usr/bin/env ruby\n" +
              LOADER +
              "require 'bundler/setup'\n" +
              "load Gem.bin_path('#{command.gem_name}', '#{command.exec_name}')\n"
            )
            command.binstub.chmod 0755
            status "generated with spring"
          end
        end
      end

      attr_reader :bindir, :items

      def self.description
        "Generate spring based binstubs. Use --all to generate a binstub for all known commands."
      end

      def self.rails_command
        @rails_command ||= CommandWrapper.new("rails")
      end

      def self.call(args)
        require "spring/commands"
        super
      end

      def initialize(args)
        super

        @bindir = env.root.join("bin")
        @items  = args.drop(1)
                      .map { |name| find_commands name }
                      .inject(Set.new, :|)
                      .map { |command| Item.new(command) }
      end

      def find_commands(name)
        case name
        when "--all"
          commands = Spring.commands.dup
          commands.delete_if { |name, _| name.start_with?("rails_") }
          commands.values + [self.class.rails_command]
        when "rails"
          [self.class.rails_command]
        else
          if command = Spring.commands[name]
            [command]
          else
            $stderr.puts "The '#{name}' command is not known to spring."
            exit 1
          end
        end
      end

      def call
        bindir.mkdir unless bindir.exist?
        generate_spring_binstub
        items.each(&:add)
      end

      def generate_spring_binstub
        File.write(bindir.join("spring"), <<CODE)
#!/usr/bin/env ruby

unless defined?(Spring)
  require "rubygems"
  require "bundler"

  ENV["GEM_HOME"] = ""
  ENV["GEM_PATH"] = Bundler.bundle_path.to_s
  Gem.paths = ENV

  require "spring/binstub"
end
CODE

        bindir.join("spring").chmod 0755
      end
    end
  end
end
