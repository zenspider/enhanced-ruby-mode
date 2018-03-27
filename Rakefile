task :default => "test:all"

namespace :test do
  desc "Run tests for Ruby"
  task :ruby do
    sh(%q[ruby -I. test/test_erm_buffer.rb]){}
  end

  desc "Run tests for Emacs Lisp"
  task :elisp do
    Dir.chdir "test" do
      sh(%q[emacs --batch -Q -l enh-ruby-mode-test.el -f ert-run-tests-batch-and-exit]){}
    end
  end

  desc "Run tests for Emacs Lisp interactively"
  task :elispi do
    Dir.chdir "test" do
      sh(%q[emacs -Q -l enh-ruby-mode-test.el -eval "(ert-run-tests-interactively 't)"]){}
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
