if [ "" != "`which rbenv 2> /dev/null `" ] ; then
    eval " $(rbenv init - )"

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
      to_install=bundler
      install_version=
      while [ "$to_install" != "" ] ; do
          cmd="gem install $to_install"
          if [ "$install_version" != "" ] ; then
              cmd="$cmd -v $install_version"
          fi
          echo "Trying to install $to_install -v $install_version" # [press enter to continue]"
          #read blah
          $cmd

          stat=$(bundle list | grep "Could not find gem" | extsed -r "s/^.*Could not find gem '([^ ]+).*[^0-9.]([0-9.]+)[^0-9].*$/\1 \2/")

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

fi

if [ "" != "`which rspec 2> /dev/null `" ] ; then
    alias rspec="rspec -c -f d"
fi

