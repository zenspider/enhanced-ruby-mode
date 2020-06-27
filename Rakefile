task :default => %w[clean test:all compile]

def run cmd
  sh cmd do |good|
    # block prevents ruby backtrace on failure
    exit 1 unless good
  end
end

def emacs args
  emacs_cmd = Dir[
    "/usr/local/bin/emacs",
    "/{My,}Applications/Emacs.app/Contents/MacOS/Emacs" # homebrew
  ].first || "emacs" # trust the path

  run %Q[#{emacs_cmd} #{args}]
end

def emacs_test args
  emacs "-Q -l enh-ruby-mode-test.el #{args}"
end

desc "byte compile the project. Helps drive out warnings, but also faster."
task :compile do
  emacs "--batch -f batch-byte-compile enh-ruby-mode.el"
end

desc "Clean the project"
task :clean do
  rm_f Dir["**/*~", "**/*.elc"]
end

namespace :test do
  desc "Run tests for Ruby"
  task :ruby do
    n = ENV["N"]

    if n then
      run %Q[ruby -wI. test/test_erm_buffer.rb -n #{n.dump}]
    else
      run %Q[ruby -wI. test/test_erm_buffer.rb]
    end
  end

  desc "Run tests for Emacs Lisp"
  task :elisp do
    n=ENV["N"]

    Dir.chdir "test" do
      if n then
        emacs_test "--batch -eval '(ert-run-tests-batch-and-exit #{n.dump})'"
      else
        emacs_test "--batch -f ert-run-tests-batch-and-exit"
      end
    end
  end

  desc "Run tests for Emacs Lisp interactively"
  task :elispi do
    Dir.chdir "test" do
      emacs_test %q[-eval "(ert-run-tests-interactively 't)"]
    end
  end

  desc "Run test:ruby and test:elisp"
  task :all => [:ruby, :elisp]
end

desc "build on circleci? does this work?"
task :circleci do
  sh "circleci build"
end

def docker cmd
  sh %(docker run -v $PWD:/erm --rm -i -t -w /erm/test zenspider/emacs-ruby #{cmd})
end

desc "test in a docker container"
task :docker do
  docker "rake test:all"
end

desc "interactive test in a docker container"
task :dockeri do
  docker "rake test:elispi"
end

desc "run a shell in a docker container"
task :sh do
  docker "/bin/sh"
end

desc "debug a file (F=path)"
task :debug do
  f = ENV["F"]
  system "ruby tools/debug.rb #{f}"
  puts
  system "ruby tools/lexer.rb #{f}"
  puts
  system "ruby tools/markup.rb #{f}"
end
