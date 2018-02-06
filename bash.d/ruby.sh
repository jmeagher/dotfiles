if [ "" != "`which rbenv 2> /dev/null `" ] ; then
    eval " $(rbenv init - )"

    # Handy ruby things
    alias be="bundle exec"

    # If there's a better way to do this please let me know
    # This works for me when using rbenv and works on the projects I work on
    function rt() {
      if [ "$1" = "" ] ; then
        bundle exec rake spec
      else
        bundle exec rspec "$@"
      fi
    }

    function rbenvsetup() {
      if [ ! -e .ruby-version ] ; then
          rbenv global > .ruby-version 
      fi

      rbenv gemset version 2>&1 > /dev/null
      r=$?
      if [ $r -eq 0 ] ; then
          if [ ! -e .ruby-gemset ] ; then
              echo "Enter gemset name"
              read gs
              echo $gs > .ruby-gemset
              unset gs
          fi
      fi


      echo "Install bundler? ctrl-c to quit, enter to continue"
      read a
      echo "Ok, installing..."
      gem install bundler --no-rdoc --no-ri
      unset a

    }

    # Does a walk through the gem list trying to figure out what isn't installing right
    function gem_step_install() {
      to_install=$1
      install_version=
      if [ "$to_install" = "" ] ; then
          to_install=nothing
      fi
      while [ "$to_install" != "" ] ; do
          if [ "$to_install" != "nothing" ] ; then
            cmd="gem install $to_install"
            if [ "$install_version" != "" ] ; then
                cmd="$cmd -v $install_version"
            fi
            echo "Trying to install $to_install -v $install_version" # [press enter to continue]"
            #read blah
            $cmd
          fi

          stat=$(bundle list | grep "Could not find gem" | extsed "s/^.*Could not find gem '([^ ]+).*[^0-9.]([0-9.]+)[^0-9].*$/\1 \2/")

          old_install=$to_install
          to_install=${stat%% *}
          install_version=${stat##* }
          if [ "$install_version" = "0" ] ; then
              install_version=
          fi

          if [ "$old_install" = "$to_install" ] ; then
              to_install=
              echo "It looks like the installation of $old_install failed, check things and try again"
          fi
      done
    }

    function ruby_stack() {
      pid=$1
      gdb $(which ruby) $pid  <<STACKGEN_END
          ruby_stack
          detach
          quit
STACKGEN_END

    }

  if [ "" != "`which rspec 2> /dev/null `" ] ; then
      alias rspec="rspec -c -f d"
  fi
else
  # Fallback to setup a basic rbenv environment
  function rbenvsetup() {
    echo "If you're in a mac run 'brew install rbenv rbenv-build rbenv-gemset', if not hit enter to install things the manual way or ctrl-C to quit"
    read a
    (cd ~ && git clone https://github.com/sstephenson/rbenv.git ~/.rbenv)

    # For installing ruby versions
    git clone https://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build

    # For having gemsets for gem isolation
    mkdir -p ~/.rbenv/plugins
    cd ~/.rbenv/plugins
    git clone git://github.com/jamis/rbenv-gemset.git
    
    echo "Things are setup, run rebash now to fix up your environment"
  }
fi


if [ "" != "`which rvm 2> /dev/null `" ] ; then
  [[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
  export PATH="$PATH:$HOME/.rvm/bin"
fi

