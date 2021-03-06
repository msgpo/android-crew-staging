require_relative '../exceptions.rb'
require_relative '../formulary.rb'
require_relative 'command.rb'
require_relative 'info/options.rb'


module Crew

  def self.info(args)
    Info.new(args).execute
  end

  class Info < Command

    attr_reader

    def initialize(args)
      super args, Options
      raise FormulaUnspecifiedError if args.count < 1
    end

    def execute
      args.each.with_index do |name, index|
        formulas = formulary.find(name)
        raise FormulaUnavailableError.new(name) if formulas.size == 0
        formulas.each.with_index do |formula, num|
          case options.show_info
          when :versions
            puts formula.releases.select { |r| not r.obsolete? }.map(&:to_s).join(' ')
          when :path
            puts formula.path
          else
            print_info formula
            puts "" if num + 1 < formulas.count
          end
        end
        puts "" if index + 1 < args.count
      end
    end

    def print_info(formula)
      releases = []
      formula.releases.each do |r|
        unless formula.installed?(r)
          installed = ''
        else
          installed =  ' (*'
          if formula.has_dev_files?
            installed += formula.dev_files_installed?(r) ? '/*' : '/'
          end
          installed += ')'
        end
        releases << "#{r.version} #{r.crystax_version}#{installed}"
      end

      puts "Name:               #{formula.name}"
      puts "Namespace:          #{formula.namespace}"
      puts "Formula:            #{formula.path}"
      puts "Homepage:           #{formula.homepage}"
      puts "Description:        #{formula.desc}"
      puts "Class:              #{formula.class.name}"
      puts "Releases:           #{releases.join(', ')}"
      puts "Dependencies:       #{format_dependencies(formula.dependencies)}"
      puts "Build dependencies: #{format_dependencies(formula.build_dependencies)}"

      if formula.support_dev_files?
        s = formula.has_dev_files? ? 'yes' : 'no'
        puts "Has dev files:      #{s}"
      end

      puts "Build info:"
      options.build_info_platforms.each do |platform|
        formula.releases.each do |release|
          puts "#{platform}, #{release}"
          host_bi, target_bi = formula.build_info(release, platform).partition { |a| a.start_with? 'host/' }
          host_bi.map! { |a| a.delete_prefix('host/')}
          target_bi.map! { |a| a.delete_prefix('target/')}
          puts "  host:   #{host_bi.join(', ')}"
          puts "  target: #{target_bi.join(', ')}"
        end
      end
    end

    def format_dependencies(deps)
      res = []
      deps.each do |d|
        installed = formulary[d.fqn].installed? ? ' (*)' : ''
        res << "#{d.name}#{installed}"
      end
      res.size > 0 ? res.join(', ') : 'none'
    end
  end
end
