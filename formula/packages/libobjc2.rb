class Libobjc2 < Package

  desc 'GNUstep Objective-C Runtime'
  homepage 'https://github.com/gnustep/libobjc2'
  url 'https://github.com/crystax/android-vendor-libobjc2.git|commit:36d73233f25183d7f371176e0417ca1c94c43c6f'

  release '1.8.1', crystax: 6

  build_options build_outside_source_tree: false,
                setup_env: false

  def build_for_abi(abi, _toolchain, _release, _options)
    install_dir = install_dir_for_abi(abi)

    args = ["-DWITH_TESTS=NO",
	    "-DCMAKE_INSTALL_PREFIX=#{install_dir}",
	    "-DCMAKE_TOOLCHAIN_FILE=#{Build::CMAKE_TOOLCHAIN_FILE}",
            "-DCMAKE_MAKE_PROGRAM=make",
	    "-DANDROID_ABI=#{abi}",
	    "-DANDROID_TOOLCHAIN_VERSION=clang#{Toolchain::DEFAULT_LLVM.version}",
	    "."
           ]

    # cmake (on linux) is built with curl
    # this should prevent system cmake using our libcurl or any other libs from prebuilt/*/lib
    build_env['LD_LIBRARY_PATH'] = nil if Global::OS == 'linux'

    system 'cmake', *args
    system 'make', '-j', num_jobs
    system 'make', 'install'

    internal_headers_dir = File.join(install_dir, 'include', 'internal')
    FileUtils.mkdir_p internal_headers_dir
    FileUtils.cp ['class.h', 'visibility.h'], internal_headers_dir
  end
end
