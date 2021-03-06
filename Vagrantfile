# -*- mode: ruby -*-
# vi: set ft=ruby :

# This Vagrantfile creates a build machine for our traceview gem.
# Usage:
# $ vagrant up
# $ vagrant ssh
# $ ./build_gems.bash

# Your rubygems push credentials, if saved.
dot_gem_credentials = File.expand_path(ENV['vg_dot_gem_credentials'] || '~/.gem/credentials')

Vagrant.configure("2") do |config|

  config.vm.box = "ubuntu/trusty64"

  config.vm.provision "shell", privileged: false, inline: <<-SHELL
    # install OS packages
    sudo apt-get update
    sudo apt-get install -y build-essential curl git-core libssl-dev libreadline-dev openjdk-7-jdk zlib1g-dev

    # rbenv setup
    git clone https://github.com/rbenv/rbenv.git ~/.rbenv
    git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.profile
    echo 'eval "$(rbenv init -)"' >> ~/.profile
    . ~/.profile

    # install rubies to build our gem against
    rbenv install 2.3.1
    rbenv install jruby-9.0.5.0
  SHELL

  if File.exist? dot_gem_credentials
    config.vm.provision "file",
                        source: dot_gem_credentials,
                        destination: "~/.gem/credentials"
  end

  config.vm.provision "shell", privileged: false, inline: <<-SHELL
      cat <<'BUILDSCRIPT'> ~/build_gems.bash
#!/usr/bin/env bash
cd /vagrant
export RBENV_VERSION=jruby-9.0.5.0
jruby -S gem build traceview.gemspec

export RBENV_VERSION=2.3.1
gem build traceview.gemspec

ls -la traceview*.gem

echo "publish to rubygems via: gem push <gem>"
BUILDSCRIPT
      chmod 755 ~/build_gems.bash
  SHELL

end
