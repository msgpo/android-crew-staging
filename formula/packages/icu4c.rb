class Icu4c < Package

  desc "C/C++ and Java libraries for Unicode and globalization"
  homepage "http://site.icu-project.org/"
  url 'https://dl.crystax.net/mirror/icu4c-${version}.tgz'

  release '64.2', crystax: 2

  # todo: 'libiculx' requires harfbuzz
  build_libs 'libicudata', 'libicui18n', 'libicuio', 'libicutest', 'libicutu', 'libicuuc'
  build_copy 'license.html'
  build_options use_cxx: true,
                build_outside_source_tree: false

  def pre_build(src_dir, _release)
    base_dir = build_base_dir
    build_dir = "#{build_base_dir}/native"
    FileUtils.mkdir_p build_dir
    FileUtils.cp_r "#{src_dir}/.", build_dir

    # todo: there are problems when using prebuilt gcc on darwin systems
    unless Global::OS == 'darwin'
      Build.gen_host_compiler_wrapper "#{build_dir}/gcc", 'gcc'
      Build.gen_host_compiler_wrapper "#{build_dir}/g++", 'g++'

      build_env['PATH'] = "#{build_dir}:#{ENV['PATH']}"
      build_env['ICULEHB_LIBS']   = ' '
    end

    FileUtils.cd(build_dir) do
      system './source/runConfigureICU', icu_host_platform
      system 'make', '-j', num_jobs
    end

    build_dir
  end

  def build_for_abi(abi, _toolchain, release, _options)
    native_build_dir = pre_build_result
    install_dir = install_dir_for_abi(abi)
    args = [ "--prefix=#{install_dir}",
             "--host=#{host_for_abi(abi)}",
             "--enable-shared",
             "--enable-static",
             "--disable-tests",
             "--disable-samples",
             "--with-cross-build=#{native_build_dir}"
           ]

    build_env['CFLAGS']  << ' -fPIC -DU_USING_ICU_NAMESPACE=0 -DU_CHARSET_IS_UTF8=1'
    build_env['LDFLAGS'] << ' -lgnustl_shared'

    build_env['ICULEHB_LIBS']   = ' '

    system './source/configure', *args
    make
    make 'install'

    clean_install_dir abi
    FileUtils.cd("#{install_dir}/lib") do
      FileUtils.rm_rf ['icu'] + Dir['libiculx.*']
      build_libs.each { |f| FileUtils.mv "#{f}.so.#{release.version}", "#{f}.so" }
    end
  end

  def icu_host_platform
    case Global::OS
    when 'darwin'
      'MacOSX/GCC'
    when 'linux'
      'Linux/gcc'
    else
      raise 'unsuppoted ICU host platform'
    end
  end

  def sonames_translation_table(release)
    v = major_ver(release)
    table = {}
    build_libs.each { |l| table["#{l}.so.#{v}"] = l }
    table
  end

  def major_ver(release)
    release.version.split('.')[0]
  end
end
