# @summary Installs Curator into a Python virtualenv.
#
# @api private
class curator::install {
  assert_private()

  $pip = "${curator::install_dir}/bin/pip"

  if $curator::ensure == 'present' {
    if $curator::manage_python and !$curator::python_packages.empty {
      stdlib::ensure_packages($curator::python_packages)
      $python_requires = $curator::python_packages.map |String[1] $package| { Package[$package] }
    } else {
      $python_requires = []
    }

    exec { 'curator-venv':
      command => shell_join([$curator::python, '-m', 'venv', $curator::install_dir]),
      creates => $pip,
      path    => ['/usr/bin', '/bin'],
      require => $python_requires,
    }

    # A direct reference with a #sha256= fragment makes pip refuse a wheel
    # whose checksum doesn't match. The dependencies are resolved from the
    # package index as usual.
    $source = $curator::_package_source
    $checksum = $curator::_checksum
    $requirement = "elasticsearch-curator @ ${source}#sha256=${checksum}"
    $installed_version = 'import sys, importlib.metadata as m; sys.exit(m.version("elasticsearch-curator") != sys.argv[1])'

    # The version check runs in a shell so it can simply fail, rather than
    # error, when the virtualenv doesn't exist yet (as in a --noop run).
    $venv_python = "${curator::install_dir}/bin/python"
    exec { 'curator-install':
      command  => shell_join([$pip, 'install', '--disable-pip-version-check', '--no-input'] + $curator::pip_options + [$requirement]),
      unless   => "${shell_join(['test', '-x', $venv_python])} && ${shell_join([$venv_python, '-c', $installed_version, $curator::version])}",
      provider => 'shell',
      path     => ['/usr/bin', '/bin'],
      timeout  => 900,
      require  => Exec['curator-venv'],
    }
  } else {
    # Only remove the directory if it is a virtualenv.
    exec { 'curator-remove-venv':
      command => shell_join(['rm', '-rf', '--', $curator::install_dir]),
      onlyif  => shell_join(['test', '-f', "${curator::install_dir}/pyvenv.cfg"]),
      path    => ['/usr/bin', '/bin'],
    }
  }
}
