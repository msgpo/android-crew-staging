require_relative 'build.rb'

class Platform

  NAMES = ['darwin-x86_64', 'linux-x86_64', 'windows-x86_64', 'windows']
  MACOSX_VERSION_MIN = '10.6'
  TOOLCHAIN = { 'darwin/darwin' => { tool_path:   "#{Build::PLATFORM_PREBUILTS_DIR}/gcc/darwin-x86/host/x86_64-apple-darwin-4.9.3/bin",
                                     tool_prefix: '',
                                     gcc:         'gcc',
                                     gxx:         'g++',
                                     ar:          'gcc-ar',
                                     ranlib:      'gcc-ranlib',
                                     # no strip in darwin/gcc toolchain
                                     nm:          'gcc-nm'
                                   },
                'linux/linux'   => { tool_path:   "#{Build::PLATFORM_PREBUILTS_DIR}/gcc/linux-x86/host/x86_64-linux-glibc2.11-4.8/bin",
                                     tool_prefix: 'x86_64-linux-',
                                     gcc:         'gcc',
                                     gxx:         'g++',
                                     ar:          'ar',
                                     ranlib:      'ranlib',
                                     strip:       'strip',
                                     nm:          'nm'
                                   },
                'linux/darwin'  => { tool_path:   "#{Build::PLATFORM_PREBUILTS_DIR}/clang/linux-x86/host/x86_64-apple-darwin15/bin",
                                     tool_prefix: 'x86_64-apple-darwin15-',
                                     gcc:         'cc',
                                     gxx:         'c++',
                                     ar:          'ar',
                                     ranlib:      'ranlib',
                                     strip:       'strip',
                                     nm:          'nm'
                                   },
                'linux/windows' => { tool_path:   "#{Build::PLATFORM_PREBUILTS_DIR}/gcc/linux-x86/host/x86_64-w64-mingw32-4.9.3/bin",
                                     tool_prefix: 'x86_64-w64-mingw32-',
                                     gcc:         'gcc',
                                     gxx:         'g++',
                                     ar:          'ar',
                                     ranlib:      'ranlib',
                                     strip:       'strip',
                                     nm:          'nm'
                                   }
              }

  attr_reader :name, :host_os, :target_os, :target_cpu
  attr_reader :cc, :cxx, :ar, :ranlib, :strip, :nm
  attr_reader :sysroot
  attr_reader :cflags, :cxxflags
  attr_reader :configure_host, :toolchain_host, :toolchain_build
  attr_reader :target_exe_ext

  def initialize(name)
    raise "unsupported platform #{name}" unless NAMES.include? name

    @name = name
    @host_os = Global::OS
    @target_os, @target_cpu = name.split('-')
    @target_cpu = 'x86' if @target_cpu == nil
    #
    os_pair = "#{@host_os}/#{@target_os}"
    raise "unsupported host OS / target OS pair: #{os_pair}" unless TOOLCHAIN[os_pair]
    toolchain = TOOLCHAIN[os_pair]
    path = toolchain[:tool_path]
    prefix = toolchain[:tool_prefix]
    @cc = File.join(path, "#{prefix}#{toolchain[:gcc]}")
    @cxx = File.join(path, "#{prefix}#{toolchain[:gxx]}")
    if @target_os == 'darwin' and @host_os == 'darwin'
      # there is a problem with lt_plugin on darwin
      @ar     = 'ar'
      @ranlib = 'ranlib'
      @strip  = 'strip'
    else
      @ar     = File.join(path, "#{prefix}#{toolchain[:ar]}")
      @ranlib = File.join(path, "#{prefix}#{toolchain[:ranlib]}")
      @strip  = File.join(path, "#{prefix}#{toolchain[:strip]}")
      @nm     = File.join(path, "#{prefix}#{toolchain[:nm]}")
    end
    #
    case @name
    when 'darwin-x86_64'
      @sysroot         = "#{Build::PLATFORM_PREBUILTS_DIR}/sysroot/darwin-x86/MacOSX10.6.sdk"
      @cflags          = "-isysroot#{sysroot} -mmacosx-version-min=#{MACOSX_VERSION_MIN} -DMACOSX_DEPLOYMENT_TARGET=#{MACOSX_VERSION_MIN} -m64"
      @configure_host  = 'x86_64-darwin10'
      @toolchain_build = (@host_os == 'darwin') ? @toolchain_build : 'x86_64-linux-gnu'
      @toolchain_host  = 'x86_64-apple-darwin'
    when 'linux-x86_64'
      @sysroot         = "#{Build::PLATFORM_PREBUILTS_DIR}/gcc/linux-x86/host/x86_64-linux-glibc2.11-4.8/sysroot"
      @cflags          = "--sysroot=#{sysroot}"
      @configure_host  = 'x86_64-linux'
      @toolchain_build = 'x86_64-linux-gnu'
      @toolchain_host  = @toolchain_build
    when 'windows-x86_64'
      @cflags          = '-m64'
      @configure_host  = 'x86_64-w64-mingw32'
      @toolchain_build = 'x86_64-linux-gnu'
      @toolchain_host  = 'x86_64-pc-mingw32msvc'
    when 'windows'
      @cflags          = '-m32'
      @configure_host  = 'x86_64-w64-mingw32'
      @toolchain_build = 'x86_64-linux-gnu'
      @toolchain_host  = 'i586-pc-mingw32msvc'
    end

    @cxxflags = @cflags

    @target_exe_ext = (@target_os == 'windows') ? '.exe' : ''
  end

  def to_sym
    @name.gsub(/-/, '_').to_sym
  end

  def target_name
    @name == 'windows-x86' ? 'windows' : @name
  end
end
