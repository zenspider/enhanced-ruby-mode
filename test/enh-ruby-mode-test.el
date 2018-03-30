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

   (goto-char (point-max))
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

   (enh-ruby-forward-sexp 1)
   (forward-char 2)
   (line-should-equal "def backward_sexp")))

(ert-deftest enh-ruby-up-sexp-test ()
  (with-temp-enh-rb-string
   "def foo\n  %_bosexp#{sdffd} test1_[1..4].si\nend"

   (search-forward "test1_")
   (enh-ruby-up-sexp)
   (line-should-equal "def foo")))      ; maybe this should be %_bosexp?

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

;;; indent-region

(ert-deftest enh-ruby-indent-array-of-strings ()
  ;; TODO: this should NOT be indented this way
  (with-deep-indent nil
    (string-should-indent "words = [\n'moo'\n]\n"
                          "words = [\n  'moo'\n]\n")))

(ert-deftest enh-ruby-indent-array-of-strings/deep ()
  (with-deep-indent t
    (string-should-indent "words = ['cow',\n'moo'\n]\n"
                          "words = ['cow',\n         'moo'\n        ]\n")))

(ert-deftest enh-ruby-indent-array-of-strings/ruby ()
  (string-should-indent-like-ruby "words = [\n'moo'\n]\n"))

(ert-deftest enh-ruby-indent-def-after-private ()
  (with-deep-indent nil
   (string-should-indent "class Foo\nprivate def foo\nx\nend\nend\n"
                         "class Foo\n  private def foo\n    x\n  end\nend\n")))

(ert-deftest enh-ruby-indent-def-after-private/deep ()
  (with-deep-indent t
   (string-should-indent "class Foo\nprivate def foo\nx\nend\nend\n"
                         "class Foo\n  private def foo\n            x\n          end\nend\n")))

(ert-deftest enh-ruby-indent-hash ()
  ;; https://github.com/zenspider/enhanced-ruby-mode/issues/78
  (with-deep-indent nil
    (string-should-indent "c = {\na: a,\nb: b\n}\n"
                          "c = {\n  a: a,\n  b: b\n}\n")))

(ert-deftest enh-ruby-indent-hash/deep ()
  ;; TODO: "c = {\n      a: a,\n      b: b\n    }\n"
  (with-deep-indent t
    (string-should-indent "c = {a: a,\nb: b,\n c: c}\n"
                          "c = {a: a,\n     b: b,\n     c: c}\n")))

(ert-deftest enh-ruby-indent-hash-after-cmd ()
  ;; https://github.com/zenspider/enhanced-ruby-mode/issues/78
  (with-deep-indent nil
    (string-should-indent "x\n{\na: a,\nb: b\n}"
                          "x\n{\n  a: a,\n  b: b\n}")))

(ert-deftest enh-ruby-indent-hash-after-cmd/deep ()
  ;; https://github.com/zenspider/enhanced-ruby-mode/issues/78
  ;; TODO: this output doesn't make sense!
  ;; either it should match non-deep or it should be *deeper*, not shallower.
  (with-deep-indent t
    (string-should-indent "x\n{\na: a,\nb: b\n}"
                          "x\n{\n a: a,\n b: b\n}")))

(ert-deftest enh-ruby-indent-hash-after-cmd/ruby ()
  ;; https://github.com/zenspider/enhanced-ruby-mode/issues/78
  (string-should-indent-like-ruby "x\n{\na: a,\nb: b\n}"))

(ert-deftest enh-ruby-indent-if-in-assignment ()
  (with-deep-indent nil
    (string-should-indent "foo = if bar\nx\nelse\ny\nend\n"
                          "foo = if bar\n  x\nelse\n  y\nend\n")))

(ert-deftest enh-ruby-indent-if-in-assignment/deep ()
  (with-deep-indent t
    (string-should-indent "foo = if bar\nx\nelse\ny\nend\n"
                          "foo = if bar\n        x\n      else\n        y\n      end\n")))

(ert-deftest enh-ruby-indent-leading-dots ()
  (string-should-indent "d.e\n.f\n"
                        "d.e\n  .f\n"))

(ert-deftest enh-ruby-indent-leading-dots-cvar ()
  (string-should-indent "@@b\n.c\n.d\n"
                        "@@b\n  .c\n  .d\n"))

(ert-deftest enh-ruby-indent-leading-dots-cvar/ruby ()
  (string-should-indent-like-ruby "@@b\n.c\n.d\n"))

(ert-deftest enh-ruby-indent-leading-dots-gvar ()
  (string-should-indent "$b\n.c\n.d\n"
                        "$b\n  .c\n  .d\n"))

(ert-deftest enh-ruby-indent-leading-dots-gvar/ruby ()
  (string-should-indent-like-ruby "$b\n.c\n.d\n"))

(ert-deftest enh-ruby-indent-leading-dots-ident ()
  (string-should-indent "b\n.c\n.d\n"
                        "b\n  .c\n  .d\n"))

(ert-deftest enh-ruby-indent-leading-dots-ident/ruby ()
  (string-should-indent-like-ruby "b\n.c\n.d\n"))

(ert-deftest enh-ruby-indent-leading-dots-ivar ()
  (string-should-indent "@b\n.c\n.d\n"
                        "@b\n  .c\n  .d\n"))

(ert-deftest enh-ruby-indent-leading-dots-ivar/ruby ()
  (string-should-indent-like-ruby "@b\n.c\n.d\n"))

(ert-deftest enh-ruby-indent-leading-dots-with-block ()
  (string-should-indent "a\n.b {}\n.c\n"
                        "a\n  .b {}\n  .c\n"))

(ert-deftest enh-ruby-indent-leading-dots-with-block/ruby ()
  (string-should-indent-like-ruby "a\n.b {}\n.c\n"))

(ert-deftest enh-ruby-indent-leading-dots-with-comment ()
  (string-should-indent "a\n.b # comment\n.c\n"
                        "a\n  .b # comment\n  .c\n"))

(ert-deftest enh-ruby-indent-leading-dots-with-comment/ruby ()
  (string-should-indent-like-ruby "a\n.b # comment\n.c\n"))

(ert-deftest enh-ruby-indent-leading-dots/ruby ()
  (string-should-indent-like-ruby "d.e\n.f\n"))

(ert-deftest enh-ruby-indent-not-on-eol-opening/deep ()
  (with-deep-indent t
   (string-should-indent "\nfoo(:bar,\n:baz)\nfoo(\n:bar,\n:baz,\n)\n[:foo,\n:bar]\n[\n:foo,\n:bar\n]"
                         "\nfoo(:bar,\n    :baz)\nfoo(\n  :bar,\n  :baz,\n)\n[:foo,\n :bar]\n[\n  :foo,\n  :bar\n]")))

(ert-deftest enh-ruby-indent-pct-w-array ()
  (with-deep-indent nil
    (string-should-indent "words = %w[\na\nb\n]\n"
                          "words = %w[\n  a\n  b\n]\n")))

(ert-deftest enh-ruby-indent-pct-w-array/deep ()
  ;; TODO: I do NOT like this one
  ;; TODO: "words = %w[ a\n            b\n            c\n          ]\n"
  (with-deep-indent t
    (string-should-indent "words = %w[ a\nb\nc\n]\n"
                          "words = %w[ a\n         b\n         c\n        ]\n")))

(ert-deftest enh-ruby-indent-pct-w-array/ruby ()
  :expected-result :failed              ; I think ruby-mode is wrong here
  (string-should-indent-like-ruby "words = %w[ a\nb\nc\n]\n"))

(ert-deftest enh-ruby-indent-trailing-dots ()
  (string-should-indent "a.b.\nc\n"
                        "a.b.\n  c\n"))

(ert-deftest enh-ruby-indent-trailing-dots/ruby ()
  (string-should-indent-like-ruby "a.b.\nc\n"))

;;; indent-for-tab-command -- seems different than indent-region in some places

(ert-deftest enh-ruby-indent-for-tab-heredocs/off ()
  (with-temp-enh-rb-string
   "meth <<-DONE\n  a b c\nd e f\nDONE\n"

   (search-forward "d e f")
   (move-beginning-of-line nil)
   (let ((enh-ruby-preserve-indent-in-heredocs nil))
     (indent-for-tab-command)           ; hitting TAB char
     (buffer-should-equal "meth <<-DONE\n  a b c\nd e f\nDONE\n"))))

(ert-deftest enh-ruby-indent-for-tab-heredocs/on ()
  (with-temp-enh-rb-string
   "meth <<-DONE\n  a b c\nd e f\nDONE\n"

   (search-forward "d e f")
   (move-beginning-of-line nil)
   (let ((enh-ruby-preserve-indent-in-heredocs t))
     (indent-for-tab-command)           ; hitting TAB char
     (buffer-should-equal "meth <<-DONE\n  a b c\n  d e f\nDONE\n"))))

(ert-deftest enh-ruby-indent-for-tab-heredocs/unset ()
  (with-temp-enh-rb-string
   "meth <<-DONE\n  a b c\nd e f\nDONE\n"

   (search-forward "d e f")
   (move-beginning-of-line nil)
   (indent-for-tab-command)             ; hitting TAB char
   (buffer-should-equal "meth <<-DONE\n  a b c\nd e f\nDONE\n")))

;;; enh-ruby-toggle-block

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
  :expected-result t ; https://github.com/zenspider/enhanced-ruby-mode/issues/132
  (with-temp-enh-rb-string
   "7.times { |i|\n  puts \"number #{i+1}\"\n}\n"

   (toggle-to-do)))

(ert-deftest enh-ruby-toggle-block/do ()
  (with-temp-enh-rb-string
   "7.times do |i|\n  puts \"number #{i+1}\"\nend\n"

   (toggle-to-brace)))
