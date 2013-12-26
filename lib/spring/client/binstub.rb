require 'set'

module Spring
  module Client
    class Binstub < Command
      SHEBANG = /\#\!.*\n/

      # If loading the bin/spring file works, it'll run spring which will
      # eventually call Kernel.exit. This means that in the client process
      # we will never execute the lines after this block. But if the spring
      # client is not invoked for whatever reason, then the Kernel.exit won't
      # happen, and so we'll fall back to the lines after this block, which
      # should cause the "unsprung" version of the command to run.
      LOADER = <<CODE
begin
  load File.expand_path("../spring", __FILE__)
rescue LoadError
end
CODE

      # The defined? check ensures these lines don't execute when we load the
      # binstub from the application process. Which means that in the application
      # process we'll execute the lines which come after the LOADER block, which
      # is what we want.
      #
      # Gem.try_activate would be called inside rubygems due to the #require.
      # However, when that happens $! gets set and it appears that there is a
      # LoadError, which can cause problems. So we activate the gem separately
      # to requiring the file.
      SPRING = <<CODE
#!/usr/bin/env ruby

unless defined?(Spring)
  require "rubygems"
  require "bundler"

  ENV["GEM_HOME"] = ""
  ENV["GEM_PATH"] = Bundler.bundle_path.to_s
  Gem.paths = ENV

  Gem.try_activate("spring/binstub")
  require "spring/binstub"
end
CODE

      OLD_BINSTUB = %{if !Process.respond_to?(:fork) || Gem::Specification.find_all_by_name("spring").empty?}

      class Item
        attr_reader :command, :existing

        def initialize(command)
          @command = command

          if command.binstub.exist?
            @existing = command.binstub.read
          elsif command.name == "rails"
            scriptfile = Spring.application_root_path.join("script/rails")
            @existing = scriptfile.read if scriptfile.exist?
          end
        end

        def status(text, stream = $stdout)
          stream.puts "* #{command.binstub_name}: #{text}"
        end

        def add
          if existing
            if existing.include?(OLD_BINSTUB)
              fallback = existing.match(/#{Regexp.escape OLD_BINSTUB}\n(.*)else/m)[1]
              fallback.gsub!(/^  /, "")
              fallback = nil if fallback.include?("exec")
              generate(fallback)
              status "upgraded"
            elsif existing =~ /load .*spring/
              status "spring already present"
            else
              head, shebang, tail = existing.partition(SHEBANG)

              if shebang.include?("ruby")
                unless command.binstub.exist?
                  FileUtils.touch command.binstub
                  command.binstub.chmod 0755
                end

                File.write(command.binstub, "#{head}#{shebang}#{LOADER}#{tail}")
                status "spring inserted"
              else
                status "doesn't appear to be ruby, so cannot use spring", $stderr
                exit 1
              end
            end
          else
            generate
            status "generated with spring"
          end
        end

        def generate(fallback = nil)
          unless fallback
            fallback = "require 'bundler/setup'\n" \
                       "load Gem.bin_path('#{command.gem_name}', '#{command.exec_name}')\n"
          end

          File.write(command.binstub, "#!/usr/bin/env ruby\n#{LOADER}#{fallback}")
          command.binstub.chmod 0755
        end

        def remove
          if existing
            File.write(command.binstub, existing.sub(LOADER, ""))
            status "spring removed"
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
        @all    = false
        @mode   = :add
        @items  = args.drop(1)
                      .map { |name| find_commands name }
                      .inject(Set.new, :|)
                      .map { |command| Item.new(command) }
      end

      def find_commands(name)
        case name
        when "--all"
          @all = true
          commands = Spring.commands.dup
          commands.delete_if { |name, _| name.start_with?("rails_") }
          commands.values + [self.class.rails_command]
        when "--remove"
          @mode = :remove
          []
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
        case @mode
        when :add
          bindir.mkdir unless bindir.exist?

          unless spring_binstub.exist?
            File.write(spring_binstub, SPRING)
            spring_binstub.chmod 0755
          end

          items.each(&:add)
        when :remove
          spring_binstub.delete if @all
          items.each(&:remove)
        else
          raise ArgumentError
        end
      end

      def spring_binstub
        bindir.join("spring")
      end
    end
  end
end
