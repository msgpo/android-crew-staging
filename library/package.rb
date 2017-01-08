require 'fileutils'
require 'digest'
require_relative 'formula.rb'
require_relative 'properties.rb'
require_relative 'release.rb'
require_relative 'build.rb'
require_relative 'build_options.rb'


class Package < Formula

  namespace :target

  include Properties

  SRC_DIR_BASENAME = 'src'

  DEF_BUILD_OPTIONS = { source_archive_without_top_dir: false,
                        c_wrapper:                      'cc',
                        sysroot_in_cflags:              true,
                        use_cxx:                        false,
                        cxx_wrapper:                    'c++',
                        setup_env:                      true,
                        copy_installed_dirs:            ['lib', 'include'],
                        gen_android_mk:                 true,
                        wrapper_fix_soname:             true,
                        wrapper_fix_stl:                false,
                        wrapper_filter_out:             nil,
                        wrapper_remove_args:            [],
                        wrapper_replace_args:           {}
                      }.freeze

  attr_reader :pre_build_result, :post_build_result

  def initialize(path)
    super path

    # mark installed releases and sources
    releases.each { |r| r.update get_properties(release_directory(r)) }

    @pre_build_result = nil
  end

  def home_directory
    File.join(Global::HOLD_DIR, file_name)
  end

  def release_directory(release)
    File.join(home_directory, release.version)
  end

  def cache_file(release)
    File.join(Global::PKG_CACHE_DIR, archive_filename(release))
  end

  def install_archive(release, archive, _platform_name = nil)
    rel_dir = release_directory(release)
    FileUtils.rm_rf binary_files(rel_dir)
    Utils.unpack archive, rel_dir

    # todo:
    #update_root_android_mk release

    prop = get_properties(rel_dir)
    prop[:installed] = true
    prop[:source_installed] = release.source_installed?
    prop[:installed_crystax_version] = release.crystax_version
    save_properties prop, rel_dir

    release.installed = release.crystax_version
  end

  def uninstall(release)
    puts "removing #{name}:#{release.version}"
    rel_dir = release_directory(release)
    if not release.source_installed?
      FileUtils.rm_rf rel_dir
    else
      prop = get_properties(rel_dir)
      FileUtils.rm_rf binary_files(rel_dir)
      prop[:installed] = false
      save_properties prop, rel_dir
    end
    release.installed = false
  end

  def source_installed?(release = Release.new)
    releases.any? { |r| r.match?(release) and r.source_installed? }
  end

  def install_source(release)
    puts "installing source code for #{name}:#{release}"
    rel_dir = release_directory(release)
    prop = get_properties(rel_dir)
    if prop[:installed_crystax_version] == nil
      prop[:installed_crystax_version] = release.crystax_version
      FileUtils.mkdir_p rel_dir
    end

    prepare_source_code release, rel_dir, SRC_DIR_BASENAME, '='

    release.source_installed = release.crystax_version
    prop[:source_installed] = true
    save_properties prop, rel_dir
  end

  def uninstall_source(release)
    puts "uninstalling source code for #{name}:#{release.version}"
    rel_dir = release_directory(release)
    if not release.installed?
      FileUtils.rm_rf rel_dir
    else
      prop = get_properties(rel_dir)
      FileUtils.rm_r File.join(rel_dir, SRC_DIR_BASENAME)
      prop[:source_installed] = false
      save_properties prop, rel_dir
    end
    release.source_installed = false
  end

  def build(release, options, host_dep_dirs, target_dep_dirs)
    arch_list = Build.abis_to_arch_list(options.abis)
    puts "Building #{name} #{release} for architectures: #{arch_list.map{|a| a.name}.join(' ')}"

    base_dir = build_base_dir
    FileUtils.rm_rf base_dir
    src_dir = "#{release_directory(release)}/#{SRC_DIR_BASENAME}"
    @log_file = build_log_file
    @num_jobs = options.num_jobs

    if self.respond_to? :pre_build
      print "= executing pre build step: "
      @pre_build_result = pre_build(src_dir, release)
      puts @pre_build_result ? @pre_build_result : 'OK'
    end

    toolchain = Build::DEFAULT_TOOLCHAIN

    FileUtils.mkdir_p package_dir
    arch_list.each do |arch|
      puts "= building for architecture: #{arch.name}"
      arch.abis_to_build.each do |abi|
        puts "  building for abi: #{abi}"
        FileUtils.mkdir_p base_dir_for_abi(abi)
        build_dir = build_dir_for_abi(abi)
        FileUtils.cp_r "#{src_dir}/.", build_dir
        setup_build_env abi, toolchain if build_options[:setup_env]
        FileUtils.cd(build_dir) { build_for_abi abi, toolchain, release, host_dep_dirs, target_dep_dirs }
        copy_installed_files abi
        FileUtils.rm_rf base_dir_for_abi(abi) unless options.no_clean?
      end
    end

    Build.gen_android_mk "#{package_dir}/Android.mk", build_libs, build_options if build_options[:gen_android_mk]

    if self.respond_to? :post_build
      print "= executing post build step: "
      @post_build_result = post_build(package_dir, release)
      puts @post_build_result ? @post_build_result : 'OK'
    end

    build_copy.each { |f| FileUtils.cp "#{src_dir}/#{f}", package_dir }
    copy_tests

    if options.build_only?
      puts "Build only, no packaging and installing"
    else
      # pack archive and copy into cache dir
      archive = cache_file(release)
      puts "Creating archive file #{archive}"
      Utils.pack(archive, package_dir)

      if options.update_shasum?
        release.shasum = Digest::SHA256.hexdigest(File.read(archive, mode: "rb"))
        update_shasum release
      end

      # install into packages (and update props if any)
      # we do not use Formula's install method here to bypass SHA256 sum checks,
      # build command is intended for a developers
      if options.install?
        puts "Unpacking archive into #{release_directory(release)}"
        install_archive release, archive
      end
    end

    if options.no_clean?
      puts "No cleanup, for build artifacts see #{base_dir}"
    else
      FileUtils.rm_rf base_dir
    end
  end

  def setup_build_env(abi, toolchain)
    cflags  = toolchain.cflags(abi)
    ldflags = toolchain.ldflags(abi)

    arch = Build.arch_for_abi(abi)
    c_comp = toolchain.c_compiler(arch, abi)
    ar, ranlib, readelf = toolchain.tools(arch)

    if build_options[:sysroot_in_cflags]
      cflags += " --sysroot=#{Build.sysroot(abi)}"
    else
      c_comp += " --sysroot=#{Build.sysroot(abi)}"
    end

    if not build_options[:c_wrapper]
      cc = c_comp
    else
      cc = build_options[:c_wrapper] == true ? toolchain.c_compiler_name : build_options[:c_wrapper]
      cc = "#{build_dir_for_abi(abi)}/#{cc}"
      Build.gen_compiler_wrapper cc, c_comp, toolchain, build_options
    end

    @build_env = {'CC'      => cc,
                  'CPP'     => "#{cc} #{cflags} -E",
                  'AR'      => ar,
                  'RANLIB'  => ranlib,
                  'READELF' => readelf,
                  'CFLAGS'  => cflags,
                  'LDFLAGS' => ldflags
                 }

    if build_options[:use_cxx]
      cxx_comp = toolchain.cxx_compiler(arch, abi)
      cxx_comp += " --sysroot=#{Build.sysroot(abi)}" unless build_options[:sysroot_in_cflags]

      if not build_options[:cxx_wrapper]
        cxx = cxx_comp
      else
        cxx = build_options[:cxx_wrapper] == true ? toolchain.cxx_compiler_name : build_options[:cxx_wrapper]
        cxx = "#{build_dir_for_abi(abi)}/#{cxx}"
        Build.gen_compiler_wrapper cxx, cxx_comp, toolchain, build_options
      end

      cxxflags = cflags + ' ' + toolchain.search_path_for_stl_includes(abi)

      @build_env['CXX']      = cxx
      @build_env['CXXCPP']   = "#{cxx} #{cxxflags} -E"
      @build_env['CXXFLAGS'] = cxxflags
      @build_env['LDFLAGS'] += ' ' + toolchain.search_path_for_stl_libs(abi)
    end
  end

  def copy_installed_files(abi)
    dirs = build_options[:copy_installed_dirs]
    install_dir = install_dir_for_abi(abi)
    FileUtils.mkdir_p package_dir
    dirs.each do |dir|
      case dir
      when 'bin'
        # copy binary files
        FileUtils.mkdir_p "#{package_dir}/bin"
        FileUtils.cp_r "#{install_dir}/bin", "#{package_dir}/bin/#{abi}", preserve: true
      when 'include'
        # copy headers if they were not copied yet
        FileUtils.cp_r "#{install_dir}/include", package_dir, preserve: true unless Dir.exists? "#{package_dir}/include"
      when 'lib'
        # copy libs
        FileUtils.mkdir_p "#{package_dir}/libs"
        FileUtils.cp_r "#{install_dir}/lib", "#{package_dir}/libs/#{abi}", preserve: true
      when 'share'
        # copy shared files if they were not copied yet
        FileUtils.cp_r "#{install_dir}/share", package_dir, preserve: true unless Dir.exists? "#{package_dir}/share"
      else
        raise "unsupported installed dir name: #{dir}"
      end
    end
  end

  def copy_tests
    src_tests_dir = "#{Build::VENDOR_TESTS_DIR}/#{file_name}"
    if Dir.exists? src_tests_dir
      dst_tests_dir = "#{package_dir}/tests"
      FileUtils.mkdir dst_tests_dir
      FileUtils.cp_r "#{src_tests_dir}/.", "#{dst_tests_dir}/"
    end
  end

  def update_shasum(release)
    regexp = /(release\s+version:\s+'#{release.version}',\s+crystax_version:\s+#{release.crystax_version},\s+sha256:\s+')(\h+)('.*)/
    s = File.read(path).sub(regexp, '\1' +  release.shasum + '\3')
    File.open(path, 'w') { |f| f.puts s }
  end

  class << self

    def build_copy(*args)
      if args.size == 0
        @build_copy ? @build_copy : []
      else
        @build_copy = args
      end
    end

    def build_libs(*args)
      if args.size == 0
        @build_libs ? @build_libs : [ name ]
      else
        @build_libs = args
      end
    end
  end

  def build_copy
    self.class.build_copy
  end

  def build_libs
    self.class.build_libs
  end

  def archive_filename(release, _ = nil)
    "#{file_name}-#{release}.tar.xz"
  end

  private

  def sha256_sum(release, _ = nil)
    release.shasum(:android)
  end

  def binary_files(rel_dir)
    Dir["#{rel_dir}/*"].select{ |a| File.basename(a) != SRC_DIR_BASENAME }
  end

  def build_base_dir
    "#{Build::BASE_TARGET_DIR}/#{file_name}"
  end

  def package_dir
    "#{build_base_dir}/package"
  end

  def base_dir_for_abi(abi)
    "#{build_base_dir}/#{abi}"
  end

  def build_dir_for_abi(abi)
    "#{base_dir_for_abi(abi)}/build"
  end

  def install_dir_for_abi(abi)
    "#{base_dir_for_abi(abi)}/install"
  end

  def build_log_file
    "#{build_base_dir}/build.log"
  end

  def host_for_abi(abi)
    Build.arch_for_abi(abi).host
  end
end
