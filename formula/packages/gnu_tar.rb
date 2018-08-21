class GnuTar < Package

  name 'gnu-tar'
  desc 'GNU Tar provides the ability to create tar archives, as well as various other kinds of manipulation'
  homepage 'https://www.gnu.org/software/tar/'
  url 'https://ftp.gnu.org/gnu/tar/tar-${version}.tar.xz'

  release '1.30', crystax: 3

  build_copy 'COPYING'
  build_options copy_installed_dirs: ['bin', 'libexec'],
                gen_android_mk:      false

  def build_for_abi(abi, _toolchain, _release, _options)
    args =  ["--prefix=#{install_dir_for_abi(abi)}",
             "--host=#{host_for_abi(abi)}",
             "--disable-silent-rules",
             "--disable-nls"
            ]

    configure *args
    make
    make 'install'
  end
end
