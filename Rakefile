task :default => "test:all"

namespace :test do
  desc "Run tests for Ruby"
  task :ruby do
    n = ENV["N"]

    if n then
      sh(%Q[ruby -wI. test/test_erm_buffer.rb -n #{n.dump}]){}
    else
      sh(%Q[ruby -wI. test/test_erm_buffer.rb]){}
    end
  end

  def emacs args
    emacs =
      Dir[
        "/usr/local/bin/emacs",
        "/{My,}Applications/Emacs.app/Contents/MacOS/Emacs" # homebrew
      ].first || "emacs" # trust the path

    cmd = "#{emacs} -Q -l enh-ruby-mode-test.el"

    sh(%Q[#{cmd} #{args}]){} # block prevents ruby backtrace on failure
  end

  desc "Run tests for Emacs Lisp"
  task :elisp do
    n=ENV["N"]

    Dir.chdir "test" do
      if n then
        emacs "--batch -eval '(ert-run-tests-batch-and-exit #{n.dump})'"
      else
        emacs "--batch -f ert-run-tests-batch-and-exit"
      end
    end
  end

  desc "Run tests for Emacs Lisp interactively"
  task :elispi do
    Dir.chdir "test" do
      emacs %q[-eval "(ert-run-tests-interactively 't)"]
    end
  end

  desc "Run test:ruby and test:elisp"
  task :all => [:ruby, :elisp]
end

task :circleci do
  sh "circleci build"
end

def docker cmd
  sh %(docker run -v $PWD:/erm --rm -i -t -w /erm/test zenspider/emacs-ruby #{cmd})
end

task :docker do
  docker "rake test:all"
end

task :dockeri do
  docker "rake test:elispi"
end

task :sh do
  docker "/bin/sh"
end

task :debug do
  f = ENV["F"]
  system "ruby tools/debug.rb #{f}"
  puts
  system "ruby tools/lexer.rb #{f}"
  puts
  system "ruby tools/markup.rb #{f}"
end
