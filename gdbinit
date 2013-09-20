

# Ruby related helpers
# Note: This only seems to work on linux, not osx
#
# The big one here is ruby_stack.  To call it run...
# $ gdb /usr/bin/ruby [PID]
# (gdb) ruby_stack
# ... big stack trace will pring
# (gdb) detach
# (gdb) quit
#
# I'm not sure of the original source for this, but I got it from https://github.com/talbright

define redirect_stdout
  call rb_eval_string("$_old_stdout, $stdout = $stdout, File.open('/tmp/ruby-debug.stdout.' + Process.pid.to_s, 'a'); $stdout.sync = true")
end

define redirect_stdout
  call rb_eval_string("$_old_stderr, $stderr = $stderr, File.open('/tmp/ruby-debug.stderr.' + Process.pid.to_s, 'a'); $stderr.sync = true")
end

define ruby_eval
  call(rb_p(rb_eval_string_protect($arg0,(int*)0)))
end

define ruby_stack
  set $ary = (int)backtrace(-1)
  set $count = *($ary+16)
  set $index = 0
  while $index < $count
	x/1s *((int)rb_ary_entry($ary, $index)+24)
 	set $index = $index + 1
  end
end

