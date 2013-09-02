namespace :test do
  desc "Run tests for Ruby"
  task :ruby do
    sh(%q[ruby -I. test/test_erm_buffer.rb]){}
  end

  desc "Run tests for Emacs Lisp"
  task :elisp do
    sh(%q[emacs --batch -Q -l test/enh-ruby-mode-test.el -f ert-run-tests-batch-and-exit]){}
  end

  desc "Run tests for Emacs Lisp interactively"
  task :elispi do
    sh(%q[emacs -Q -l test/enh-ruby-mode-test.el -eval "(ert-run-tests-interactively 't)"]){}
  end

  desc "Run test:ruby and test:elisp"
  task :all => [:ruby, :elisp]
end
