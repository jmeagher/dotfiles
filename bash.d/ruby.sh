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
fi

if [ "" != "`which rspec 2> /dev/null `" ] ; then
    alias rspec="rspec -c -f d"
fi

