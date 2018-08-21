class Rsync < Package

  desc "A fast, versatile, remote (and local) file-copying tool"
  homepage "https://rsync.samba.org/"
  url "https://download.samba.org/pub/rsync/src/rsync-${version}.tar.gz"

  release '3.1.3', crystax: 3

  build_copy 'COPYING'
  build_options copy_installed_dirs: ['bin']

  def build_for_abi(abi, _toolchain,  release, _options)
    args = %W[ --prefix=#{install_dir_for_abi(abi)}
               --host=#{host_for_abi(abi)}
               --with-included-popt
             ]

    configure *args
    make
    make 'install'

    clean_install_dir abi
  end
end
