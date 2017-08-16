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

task :docker do
  sh %(docker run -v $PWD:/erm --rm -i -t -w /erm/test silex/emacs -Q --batch -l enh-ruby-mode-test.el -f ert-run-tests-batch-and-exit)
end

task :dockeri do
  sh %(docker run -v $PWD:/erm --rm -i -t -w /erm/test silex/emacs -Q -l enh-ruby-mode-test.el -eval "(ert-run-tests-interactively)")
end
