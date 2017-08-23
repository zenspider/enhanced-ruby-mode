(load-file "helper.el")
(load-file "../enh-ruby-mode.el")

(local-set-key (kbd "C-c C-r")
               (lambda ()
                 (interactive)
                 (require 'ert)
                 (ert-delete-all-tests)
                 (load-file "../enh-ruby-mode.el")
                 (eval-buffer)
                 (ert-run-tests-interactively t)))

;; In batch mode, face-attribute returns 'unspecified,
;; and it causes wrong-number-of-arguments errors.
;; This is a workaround for it.
(defun erm-darken-color (name)
  (let ((attr (face-attribute name :foreground)))
    (unless (equal attr 'unspecified)
      (color-darken-name attr 20)
      "#000000")))

(ert-deftest enh-ruby-backward-sexp-test ()
  (with-temp-enh-rb-string
   "def foo\n  xxx\nend\n"

   (end-of-buffer)
   (enh-ruby-backward-sexp 1)
   (line-should-equal "def foo")))

(ert-deftest enh-ruby-backward-sexp-test-inner ()
  :expected-result :failed
  (with-temp-enh-rb-string
   "def backward_sexp\n  \"string #{expr \"another\"} word\"\nend\n"

   (search-forward " word")
   (move-end-of-line nil)
   (enh-ruby-backward-sexp 2)
   (line-should-equal "\"string #{expr \"another\"} word\"")))

(ert-deftest enh-ruby-forward-sexp-test ()
  (with-temp-enh-rb-string
   "def foo\n  xxx\n end\n\ndef backward_sexp\n  xxx\nend\n"

   (beginning-of-buffer)
   (enh-ruby-forward-sexp 1)
   (forward-char 2)
   (line-should-equal "def backward_sexp")))

(ert-deftest enh-ruby-up-sexp-test ()
  (with-temp-enh-rb-string
   "def foo\n  %_bosexp#{sdffd} test1_[1..4].si\nend"

   (search-forward "test1_")
   (enh-ruby-up-sexp)
   (line-should-equal "def foo")))      ; maybe this should be %_bosexp?

(ert-deftest enh-ruby-indent-trailing-dots ()
  (with-temp-enh-rb-string
   "a.b.\nc\n"

   (indent-region (point-min) (point-max))
   (buffer-should-equal "a.b.\n  c\n")))

(ert-deftest enh-ruby-end-of-defun ()
  (with-temp-enh-rb-string
   "class Class\ndef method\n# blah\nend # method\nend # class"

   (search-forward "blah")
   (enh-ruby-end-of-defun)
   (line-should-equal " # method")))

(ert-deftest enh-ruby-end-of-block ()
  (with-temp-enh-rb-string
   "class Class\ndef method\n# blah\nend # method\nend # class"

   (search-forward "blah")
   (enh-ruby-end-of-block)
   (line-should-equal " # method")))

(ert-deftest enh-ruby-indent-leading-dots ()
  (with-temp-enh-rb-string
   "d.e\n.f\n"

   (indent-region (point-min) (point-max))
   (buffer-should-equal "d.e\n  .f\n")))

(ert-deftest enh-ruby-indent-pct-w-array ()
  (with-temp-enh-rb-string
   "words = %w[\nmoo\n]\n"

   (indent-region (point-min) (point-max))
   (buffer-should-equal "words = %w[\n         moo\n        ]\n")))

(ert-deftest enh-ruby-indent-array-of-strings ()
  (with-temp-enh-rb-string
   "words = [\n'moo'\n]\n"

   (indent-region (point-min) (point-max))
   (buffer-should-equal "words = [\n         'moo'\n        ]\n")))

(ert-deftest enh-ruby-indent-hash ()
  ;; https://github.com/zenspider/enhanced-ruby-mode/issues/78
  (with-temp-enh-rb-string
   "{\na: a,\nb: b\n}\n"

   (indent-region (point-min) (point-max))
   (buffer-should-equal "{\n a: a,\n b: b\n}\n")))

(ert-deftest enh-ruby-indent-hash-after-cmd ()
  ;; https://github.com/zenspider/enhanced-ruby-mode/issues/78
  :expected-result :failed
  (with-temp-enh-rb-string
   "x\n{\na: a,\nb: b\n}"

   (indent-region (point-min) (point-max))
   (buffer-should-equal "x\n{\n a: a,\n b: b\n}")))

(defun toggle-to-do ()
  (enh-ruby-toggle-block)
  (buffer-should-equal "7.times do |i|\n  puts \"number #{i+1}\"\nend\n"))

(defun toggle-to-brace ()
  (enh-ruby-toggle-block)
  (buffer-should-equal "7.times { |i| puts \"number #{i+1}\" }\n"))

(ert-deftest enh-ruby-toggle-block/both ()
  (with-temp-enh-rb-string
   "7.times { |i|\n  puts \"number #{i+1}\"\n}\n"

   (toggle-to-do)
   (toggle-to-brace)))

(ert-deftest enh-ruby-toggle-block/brace ()
  (with-temp-enh-rb-string
   "7.times { |i|\n  puts \"number #{i+1}\"\n}\n"

   (toggle-to-do)))

(ert-deftest enh-ruby-toggle-block/do ()
  (with-temp-enh-rb-string
   "7.times do |i|\n  puts \"number #{i+1}\"\nend\n"

   (toggle-to-brace)))

(ert-deftest enh-ruby-indent-heredocs-test/unset ()
  (with-temp-enh-rb-string
   "meth <<-DONE\n  a b c\nd e f\nDONE\n"

   (search-forward "d e f")
   (move-beginning-of-line nil)
   (indent-for-tab-command)             ; hitting TAB char
   (buffer-should-equal "meth <<-DONE\n  a b c\nd e f\nDONE\n")))

(ert-deftest enh-ruby-indent-heredocs-test/on ()
  (with-temp-enh-rb-string
   "meth <<-DONE\n  a b c\nd e f\nDONE\n"

   (search-forward "d e f")
   (move-beginning-of-line nil)
   (let ((enh-ruby-preserve-indent-in-heredocs t))
     (indent-for-tab-command)           ; hitting TAB char
     (buffer-should-equal "meth <<-DONE\n  a b c\n  d e f\nDONE\n"))))

(ert-deftest enh-ruby-indent-heredocs-test/off ()
  (with-temp-enh-rb-string
   "meth <<-DONE\n  a b c\nd e f\nDONE\n"

   (search-forward "d e f")
   (move-beginning-of-line nil)
   (let ((enh-ruby-preserve-indent-in-heredocs nil))
     (indent-for-tab-command)           ; hitting TAB char
     (buffer-should-equal "meth <<-DONE\n  a b c\nd e f\nDONE\n"))))

(ert-deftest enh-ruby-deep-indent-def-after-private ()
  (with-temp-enh-rb-string
   "class Foo\nprivate def foo\nx\nend\nend\n"

   (let ((enh-ruby-deep-indent-construct t))
     (indent-region (point-min) (point-max))
     (buffer-should-equal "class Foo\n  private def foo\n            x\n          end\nend\n"))))

(ert-deftest enh-ruby-indent-def-after-private ()
  (with-temp-enh-rb-string
   "class Foo\nprivate def foo\nx\nend\nend\n"

   (let ((enh-ruby-deep-indent-construct nil))
     (indent-region (point-min) (point-max))
     (buffer-should-equal "class Foo\n  private def foo\n    x\n  end\nend\n"))))

(ert-deftest enh-ruby-deep-indent-if-in-assignment ()
  (with-temp-enh-rb-string
   "foo = if bar\nx\nelse\ny\nend\n"

   (let ((enh-ruby-deep-indent-construct t))
     (indent-region (point-min) (point-max))
     (buffer-should-equal "foo = if bar\n        x\n      else\n        y\n      end\n"))))

(ert-deftest enh-ruby-indent-if-in-assignment ()
  (with-temp-enh-rb-string
   "foo = if bar\nx\nelse\ny\nend\n"

   (let ((enh-ruby-deep-indent-construct nil))
     (indent-region (point-min) (point-max))
     (buffer-should-equal "foo = if bar\n  x\nelse\n  y\nend\n"))))
