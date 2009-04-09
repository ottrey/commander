
require 'optparse'

module Commander
  class Runner
    
    #--
    # Exceptions
    #++

    class CommandError < StandardError; end
    class InvalidCommandError < CommandError; end
    
    ##
    # Array of commands.
    
    attr_reader :commands
    
    ##
    # Global options.
    
    attr_reader :options

    ##
    # Initialize a new command runner. Optionally
    # supplying +args+ for mocking, or arbitrary usage.
    
    def initialize args = ARGV
      @args, @commands, @aliases, @options = args, {}, {}, []
      @program = program_defaults
      create_default_commands
    end
    
    ##
    # Run command parsing and execution process.
    
    def run!
      trace = false
      require_program :version, :description
      trap('INT') { abort program(:int_message) }
      global_option('-h', '--help', 'Display help documentation') { command(:help).run *@args[1..-1]; return }
      global_option('-v', '--version', 'Display version information') { say version; return } 
      global_option('-t', '--trace', 'Display backtrace when an error occurs') { trace = true }
      parse_global_options
      remove_global_options
      unless trace
        begin
          run_active_command
        rescue InvalidCommandError => e
          abort "#{e}. Use --help for more information"
        rescue \
          OptionParser::InvalidOption, 
          OptionParser::InvalidArgument,
          OptionParser::MissingArgument => e
          abort e
        rescue => e
          abort "error: #{e}. Use --trace to view backtrace"
        end
      else
        run_active_command
      end
    end
    
    ##
    # Return program version.
    
    def version
      '%s %s' % [program(:name), program(:version)]
    end
    
    ##
    # Run the active command.
    
    def run_active_command
      require_valid_command
      if alias? command_name_from_args
        active_command.run *(@aliases[command_name_from_args.to_s] + args_without_command_name)
      else
        active_command.run *args_without_command_name
      end      
    end
    
    ##
    # Assign program information.
    #
    # === Examples:
    #    
    #   # Set data
    #   program :name, 'Commander'
    #   program :version, Commander::VERSION
    #   program :description, 'Commander utility program.'
    #   program :help, 'Copyright', '2008 TJ Holowaychuk'
    #   program :help, 'Anything', 'You want'
    #   program :int_message 'Bye bye!'
    #   
    #   # Get data
    #   program :name # => 'Commander'
    #
    # === Keys:
    #
    #   :version         (required) Program version triple, ex: '0.0.1'
    #   :description     (required) Program description
    #   :name            Program name, defaults to basename of executable
    #   :help_formatter  Defaults to Commander::HelpFormatter::Terminal
    #   :help            Allows addition of arbitrary global help blocks
    #   :int_message     Message to display when interrupted (CTRL + C)
    #
    
    def program key, *args
      if key == :help and !args.empty?
        @program[:help] ||= {}
        @program[:help][args.first] = args[1]
      else
        @program[key] = *args unless args.empty?
        @program[key]
      end
    end
    
    ##
    # Creates and yields a command instance when a block is passed.
    # Otherwise attempts to return the command, raising InvalidCommandError when
    # it does not exist.
    #
    # === Examples:
    #    
    #   command :my_command do |c|
    #     c.when_called do |args|
    #       # Code
    #     end
    #   end
    #
    
    def command name, &block
      yield add_command(Commander::Command.new(name)) if block
      @commands[name.to_s]
    end
    
    ##
    # Add a global option; follows the same syntax as Command#option
    # This would be used for switches such as --version, --trace, etc.
    
    def global_option *args, &block
      switches, description = Runner.seperate_switches_from_description *args
      @options << {
        :args => args,
        :proc => block,
        :switches => switches,
        :description => description,
      }
    end
    
    ##
    # Alias command +name+ with +alias_name+. Optionally +args+ may be passed
    # as if they were being passed straight to the original command via the command-line.
    
    def alias_command alias_name, name, *args
      @commands[alias_name.to_s] = command name
      @aliases[alias_name.to_s] = args
    end
    
    ##
    # Default command +name+ to be used when no other
    # command is found in the arguments.
    
    def default_command name
      @default_command = name
    end
    
    ##
    # Add a command object to this runner.
    
    def add_command command
      @commands[command.name] = command
    end
    
    ##
    # Check if command +name+ is an alias.
    
    def alias? name
      @aliases.include? name.to_s
    end
    
    ##
    # Check if a command +name+ exists.
    
    def command_exists? name
      @commands[name.to_s]
    end
    
    ##
    # Get active command within arguments passed to this runner.
    
    def active_command
      @__active_command ||= command(command_name_from_args)
    end
    
    ##
    # Attempts to locate a command name from within the arguments.
    # Supports multi-word commands, using the largest possible match.
    
    def command_name_from_args
      @__command_name_from_args ||= (valid_command_names_from(*@args.dup).sort.last || @default_command)
    end
    
    ##
    # Returns array of valid command names found within +args+.
    
    def valid_command_names_from *args
      arg_string = args.delete_switches.join ' '
      commands.keys.find_all { |name| name if /^#{name}/.match arg_string }
    end
    
    ##
    # Help formatter instance.
    
    def help_formatter
      @__help_formatter ||= program(:help_formatter).new self
    end
    
    ##
    # Return arguments without the command name.
    
    def args_without_command_name
      removed = []
      parts = command_name_from_args.split rescue []
      @args.dup.delete_if do |arg|
        removed << arg if parts.include?(arg) and not removed.include?(arg)
      end
    end
            
    private
    
    ##
    # Returns hash of program defaults.
    
    def program_defaults
      return :help_formatter => HelpFormatter::Terminal, 
             :int_message => "\nProcess interrupted",
             :name => File.basename($0)
    end
    
    ##
    # Creates default commands such as 'help' which is 
    # essentially the same as using the --help switch.
    
    def create_default_commands
      command :help do |c|
        c.syntax = 'command help <sub_command>'
        c.summary = 'Display help documentation for <sub_command>'
        c.description = 'Display help documentation for the global or sub commands'
        c.example 'Display global help', 'command help'
        c.example "Display help for 'foo'", 'command help foo'
        c.when_called do |args, options|
          enable_paging
          if args.empty?
            say help_formatter.render 
          else
            command = command args.join(' ')
            require_valid_command command
            say help_formatter.render_command(command)
          end
        end
      end
    end
    
    ##
    # Raises InvalidCommandError when a +command+ is not found.
    
    def require_valid_command command = active_command
      raise InvalidCommandError, 'invalid command', caller if command.nil?
    end
    
    ##
    # Removes global options from args. This prevents an invalid
    # option error from occurring when options are parsed
    # again for the sub-command.
    
    def remove_global_options
      # TODO: refactor with flipflop
      options.each do |option|
        switches = option[:switches]
        past_switch, arg_removed = false, false
        @args.delete_if do |arg|
          if switches.any? { |switch| switch =~ /^#{arg}/ }
            past_switch, arg_removed = true, false
            true
          elsif past_switch && !arg_removed && arg !~ /^-/ 
            arg_removed = true
          else
            arg_removed = true
            false
          end
        end
      end
    end
            
    ##
    # Parse global command options.
    
    def parse_global_options
      options.inject OptionParser.new do |options, option|
        options.on *option[:args], &global_option_proc(option[:switches], &option[:proc])
      end.parse! @args.dup
    rescue OptionParser::InvalidOption
      # Ignore invalid options since options will be further 
      # parsed by our sub commands.
    end
    
    ##
    # Returns a proc allowing for sub-commands to inherit global options.
    # This functionality works whether a block is present for the global
    # option or not, so simple switches such as --verbose can be used
    # without a block, and used throughout all sub-commands.
    
    def global_option_proc switches, &block
      lambda do |value|
        unless active_command.nil?
          active_command.proxy_options << [Runner.switch_to_sym(switches.last), value]
        end
        yield value if block and !value.nil?
      end
    end
    
    ##
    # Raises a CommandError when the program any of the +keys+ are not present, or empty.
        
    def require_program *keys
      keys.each do |key|
        raise CommandError, "program #{key} required" if program(key).nil? or program(key).empty?
      end
    end
    
    ##
    # Return switches and description separated from the +args+ passed.

    def self.seperate_switches_from_description *args
      switches = args.find_all { |arg| arg.to_s =~ /^-/ } 
      description = args.last unless !args.last.is_a? String or args.last.match(/^-/)
      return switches, description
    end
    
    ##
    # Attempts to generate a method name symbol from +switch+.
    # For example:
    # 
    #   -h                 # => :h
    #   --trace            # => :trace
    #   --some-switch      # => :some_switch
    #   --[no-]feature     # => :feature
    #   --file FILE        # => :file
    #   --list of,things   # => :list
    
    def self.switch_to_sym switch
      switch.scan(/[\-\]](\w+)/).join('_').to_sym rescue nil
    end
    
    private
    
    def say *args #:nodoc: 
      $terminal.say *args
    end
    
  end
end
