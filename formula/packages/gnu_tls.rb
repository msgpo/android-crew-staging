class GnuTls < Package

  name 'gnu-tls'
  desc "GnuTLS is a secure communications library implementing the SSL, TLS and DTLS protocols and technologies around them"
  homepage "https://www.gnutls.org"
  url "https://www.gnupg.org/ftp/gcrypt/gnutls/v${block}/gnutls-${version}.tar.xz" do |r| r.version.split('.').first(2).join('.') end

  release version: '3.5.18', crystax_version: 1

  depends_on 'gmp'
  depends_on 'libffi'
  depends_on 'nettle'
  depends_on 'libunistring'
  depends_on 'libidn2'
  depends_on 'p11-kit'

  build_copy 'LICENSE'
  build_options use_cxx: true,
                gen_android_mk: false,
                copy_installed_dirs: ['bin', 'include', 'lib']

  def build_for_abi(abi, _toolchain, _release, _host_dep_dirs, target_dep_dirs, _options)
    install_dir = install_dir_for_abi(abi)

    build_env['CFLAGS']  += target_dep_dirs.values.inject('') { |acc, dir| "#{acc} -I#{dir}/include" }
    build_env['LDFLAGS'] += target_dep_dirs.values.inject('') { |acc, dir| "#{acc} -L#{dir}/libs/#{abi}" }
    #build_env['LIBS']     = '-lp11-kit -lidn2 -lunistring -lnettle -lhogweed -lffi -lgmp'

    args =  [ "--prefix=#{install_dir}",
              "--host=#{host_for_abi(abi)}",
              "--disable-silent-rules",
              "--disable-doc",
              "--enable-shared",
              "--enable-static",
              "--disable-nls",
              "--with-included-libtasn1",
              "--with-pic",
              "--with-sysroot"
            ]

    system './configure', *args

    fix_makefile if ['mips', 'arm64-v8a', 'mips64'].include? abi

    system 'make', '-j', num_jobs
    system 'make', 'install'

    clean_install_dir abi, :lib
  end

  # for some reason libtool for some abis does not handle dependency libs
  def fix_makefile
    replace_lines_in_file('src/Makefile') do |line|
      if not line =~ /^LIBS =[ \t]*/
        line
      else
        line.gsub('LIBS =', 'LIBS = -lp11-kit -lidn2 -lunistring -lnettle -lhogweed -lffi -lgmp -lz ')
      end
    end
  end
end