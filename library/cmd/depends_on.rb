require_relative '../exceptions.rb'
require_relative '../formulary.rb'
require_relative 'command.rb'

module Crew

  def self.depends_on(args)
    DependsOn.new(args).execute
  end

  class DependsOn < Command

    def initialize(args)
      super args
      raise "command requires one argument" if self.args.count != 1
    end

    def execute
      formula = formulary[args[0]]
      fqn = formula.fqn
      dependants = []
      formulary.each do |formula|
        if formula.dependencies.map(&:fqn).include?(fqn)
          puts formula.fqn
        end
      end
    end
  end
end
