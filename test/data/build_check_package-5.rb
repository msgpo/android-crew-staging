class BuildCheckPackage < Package

  desc "Build Check Package"
  name 'build-check-package'

  depends_on 'build-check-dep-package'

  release '5'
end
