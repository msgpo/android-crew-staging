require_relative '../exceptions.rb'
require_relative '../release.rb'
require_relative '../formulary.rb'
require_relative '../build_options.rb'


module Crew

  def self.build(args)
    raise NoBuildOnWindows if Global::OS == 'windows'

    options, args = parse_args(args)
    raise FormulaUnspecifiedError if args.count < 1

    formulary = Formulary.new

    args.each do |n|
      item, ver = n.split(':')

      found = formulary.find(item)
      raise "please, specify namespace for #{item}; more than one formula exists: #{found.map(&:fqn).join(',')}" if found.size > 1
      raise "not found formula with name #{item}" if found.size == 0
      formula = found[0]

      release = formula.find_release(Release.new(ver))
      raise "source code not installed for #{formula.name}:#{release}" if (formula.namespace == :target) and !(release.source_installed?)

      # todo: check that (build) dependencies installed for all required platforms
      deps = formula.dependencies + formula.build_dependencies
      absent = deps.select { |d| not formulary[d.fqn].installed? }
      raise "uninstalled dependencies: #{absent.map(&:fqn).join(',')}" unless absent.empty?

      host_deps, target_deps = deps.partition { |d| d.namespace == :host }

      host_dep_dirs = Hash.new { |h, k| h[k] = Hash.new }
      host_deps.each do |d|
        f = formulary[d.fqn]
        options.platforms.each do |platform|
          dep = { f.name => f.release_directory(f.highest_installed_release, platform) }
          host_dep_dirs[platform].update dep
        end
      end

      # really stupid hash behaviour: just Hash.new({}) does not work
      target_dep_dirs = {}
      target_deps.each do |d|
        f = formulary[d.fqn]
        target_dep_dirs[f.name] = f.release_directory(f.highest_installed_release)
      end

      formula.build release, options, host_dep_dirs, target_dep_dirs

      puts "" unless n == args.last
    end
  end

  def self.parse_args(args)
    opts, args = args.partition { |a| a.start_with? '--' }

    [Build_options.new(opts), args]
  end
end
