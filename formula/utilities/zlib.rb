class Zlib < Utility

  desc 'A Massively Spiffy Yet Delicately Unobtrusive Compression Library'
  homepage 'http://zlib.net/'
  url 'http://zlib.net/zlib-${version}.tar.xz'

  release version: '1.2.8', crystax_version: 1, sha256: { linux_x86_64:   '0',
                                                          darwin_x86_64:  '0',
                                                          windows_x86_64: '0',
                                                          windows:        '0'
                                                        }

  def build_for_platform(platform, release, options, _)
    install_dir = install_dir_for_platform(platform, release)

    # copy sources; zlib doesn't support build in a separate directory
    FileUtils.cp_r File.join(src_dir, '.'), '.'

    if platform.target_os == 'windows'
      puts "implement it"
      exit
      # fname = 'win32/Makefile.gcc'
      # text = File.read(fname).gsub(/^PREFIX/, '#PREFIX')
      # File.open(fname, "w") {|f| f.puts text }
      # # chop 'gcc' from the end of the string
      # env = { 'PREFIX' => cc(options).chop.chop.chop }
      # loc = options.target_cpu == 'x86' ? 'LOC=-m32' : 'LOC=-m64'
      # Commander::run env, "make -j #{options.num_jobs} #{loc} -f win32/Makefile.gcc libz.a"
      # FileUtils.mkdir_p ["#{install_dir}/lib", "#{install_dir}/include"]
      # FileUtils.cp 'libz.a', "#{install_dir}/lib/"
      # FileUtils.cp ['zlib.h', 'zconf.h'], "#{install_dir}/include/"
    else
      build_env['CC']     = platform.cc
      build_env['CFLAGS'] = platform.cflags
      build_env['LANG']   = 'C'

      args = ["--prefix=#{install_dir}",
              "--static"
             ]

      system "#{src_dir}/configure", *args
      system 'make', '-j', num_jobs
      system 'make', 'check' if options.check? platform
      system 'make', 'install'

      FileUtils.rm_rf ["#{install_dir}/share", "#{install_dir}/lib/pkgconfig"]
    end
  end
end