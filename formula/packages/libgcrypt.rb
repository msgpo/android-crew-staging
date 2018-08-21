class Libgcrypt < Package

  desc "Libgcrypt is a general purpose cryptographic library originally based on code from GnuPG"
  homepage "https://www.gnupg.org/software/libgcrypt/"
  url "https://www.gnupg.org/ftp/gcrypt/libgcrypt/libgcrypt-${version}.tar.bz2"

  release '1.8.3', crystax: 2

  depends_on 'libgpg-error'

  build_copy 'COPYING','COPYING.LIB'

  def build_for_abi(abi, _toolchain,  _release, _options)
    args =  [ "--prefix=#{install_dir_for_abi(abi)}",
              "--host=#{host_for_abi(abi)}",
              "--disable-silent-rules",
              "--enable-shared",
              "--enable-static",
              "--disable-doc",
              "--with-pic",
              "--with-sysroot"
            ]
    args << '--disable-asm' if ['x86', 'x86_64'].include? Build.arch_for_abi(abi).name

    build_env['GPG_ERROR_CFLAGS'] = "-I#{target_dep_include_dir('libgpg-error')}"
    build_env['GPG_ERROR_LIBS']   = "-L#{target_dep_lib_dir('libgpg-error', abi)} -lgpg-error"
    build_env['LDFLAGS']         += ' -lgpg-error'

    configure *args
    make
    make 'install'

    clean_install_dir abi
  end
end
