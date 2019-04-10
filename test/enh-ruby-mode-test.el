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

(enh-deftest enh-ruby-backward-sexp-test ()
  (with-temp-enh-rb-string
   "def foo\n  xxx\nend\n"

   (goto-char (point-max))
   (enh-ruby-backward-sexp 1)
   (line-should-equal "def foo")))

(enh-deftest enh-ruby-backward-sexp-test-inner ()
  :expected-result :failed
  (with-temp-enh-rb-string
   "def backward_sexp\n  \"string #{expr \"another\"} word\"\nend\n"

   (search-forward " word")
   (move-end-of-line nil)
   (enh-ruby-backward-sexp 2)
   (line-should-equal "\"string #{expr \"another\"} word\"")))

(enh-deftest enh-ruby-forward-sexp-test ()
  (with-temp-enh-rb-string
   "def foo\n  xxx\n end\n\ndef backward_sexp\n  xxx\nend\n"

   (enh-ruby-forward-sexp 1)
   (forward-char 2)
   (line-should-equal "def backward_sexp")))

(enh-deftest enh-ruby-up-sexp-test ()
  (with-temp-enh-rb-string
   "def foo\n  %_bosexp#{sdffd} test1_[1..4].si\nend"

   (search-forward "test1_")
   (enh-ruby-up-sexp)
   (line-should-equal "def foo")))      ; maybe this should be %_bosexp?

(enh-deftest enh-ruby-end-of-defun ()
  (with-temp-enh-rb-string
   "class Class\ndef method\n# blah\nend # method\nend # class"

   (search-forward "blah")
   (enh-ruby-end-of-defun)
   (rest-of-line-should-equal " # method")))

(enh-deftest enh-ruby-end-of-block ()
  (with-temp-enh-rb-string
   "class Class\ndef method\n# blah\nend # method\nend # class"

   (search-forward "blah")
   (enh-ruby-end-of-block)
   (rest-of-line-should-equal " # method")))

;;; indent-region

(enh-deftest enh-ruby-indent-array-of-strings ()
  (with-deep-indent nil
    (string-should-indent "words = [\n'moo'\n]\n"
                          "words = [\n  'moo'\n]\n")))

(enh-deftest enh-ruby-indent-array-of-strings-incl-first ()
  (with-deep-indent nil
    (string-should-indent "words = ['cow',\n'moo'\n]\n"
                          "words = ['cow',\n  'moo'\n]\n")))

(enh-deftest enh-ruby-indent-array-of-strings/deep ()
  (with-deep-indent t
    (string-should-indent "words = ['cow',\n'moo'\n]\n"
                          "words = ['cow',\n         'moo'\n        ]\n")))

(enh-deftest enh-ruby-indent-array-of-strings-incl-first/deep ()
  (with-deep-indent t
    (string-should-indent "words = ['cow',\n'moo'\n]\n"
                          "words = ['cow',\n         'moo'\n        ]\n")))

(enh-deftest enh-ruby-indent-array-of-strings/ruby ()
  (string-should-indent-like-ruby "words = [\n'moo'\n]\n"))

(enh-deftest enh-ruby-indent-array-of-strings-incl-first/ruby ()
  (string-should-indent-like-ruby "words = ['cow',\n'moo'\n]\n"
                                  'deep))

(enh-deftest enh-ruby-indent-not-method ()
  :expected-result :failed
  (string-should-indent-like-ruby
   "\nclass Object\ndef !\n100\nend\nend"))

(enh-deftest enh-ruby-indent-hanging-period-after-parens ()
  (string-should-indent-like-ruby
   ":a\n(b)\n.c"))

(enh-deftest enh-ruby-indent-hanging-period ()
  (string-should-indent-like-ruby
   ":a\nb\n.c"))

(enh-deftest enh-ruby-indent-def-after-private ()
  (with-deep-indent nil
   (string-should-indent "class Foo\nprivate def foo\nx\nend\nend\n"
                         "class Foo\n  private def foo\n    x\n  end\nend\n")))

(enh-deftest enh-ruby-indent-def-after-private/deep ()
  (with-deep-indent t
   (string-should-indent "class Foo\nprivate def foo\nx\nend\nend\n"
                         "class Foo\n  private def foo\n            x\n          end\nend\n")))

(enh-deftest enh-ruby-indent-hash ()
  ;; https://github.com/zenspider/enhanced-ruby-mode/issues/78
  (with-deep-indent nil
    (string-should-indent "c = {\na: a,\nb: b\n}\n"
                          "c = {\n  a: a,\n  b: b\n}\n")))

(setq input/indent-hash/trail "\nc = {a: a,\nb: b,\n c: c\n}")
(setq input/indent-hash/hang  "\nc = {\na: a,\nb: b,\n c: c\n}")
(setq exp/indent-hash/hang    "\nc = {\n  a: a,\n  b: b,\n  c: c\n}")
(setq exp/indent-hash/trail   "\nc = {a: a,\n     b: b,\n     c: c\n    }")
(setq exp/indent-hash/trail/8 "\nc = {a: a,\n             b: b,\n             c: c\n    }")

(defmacro with-bounce-and-hang (bounce indent1 indent2 &rest body)
  `(let ((enh-ruby-bounce-deep-indent              ,bounce)
         (enh-ruby-deep-indent-paren               t)
         (enh-ruby-hanging-brace-indent-level      (or ,indent1
                                                       enh-ruby-hanging-brace-indent-level))
         (enh-ruby-hanging-brace-deep-indent-level (or ,indent2
                                                       enh-ruby-hanging-brace-deep-indent-level)))
     ,@body))
(put 'with-bounce-and-hang 'lisp-indent-function 'defun)

(enh-deftest enh-ruby-indent-hash/deep/hang/def ()
  (with-deep-indent t
    (with-bounce-and-hang nil nil nil
      (string-should-indent input/indent-hash/hang
                            exp/indent-hash/hang))))

(enh-deftest enh-ruby-indent-hash/deep/bounce/hang/def ()
  (with-deep-indent t
    (with-bounce-and-hang t nil nil
      (string-should-indent input/indent-hash/hang
                            "\nc = {\n     a: a,\n     b: b,\n     c: c\n    }"))))

;; if bounce off, hanging-brace-deep-indent-level doesn't matter
(enh-deftest enh-ruby-indent-hash/deep/hang/99 ()
  (with-deep-indent t
    (with-bounce-and-hang nil nil 99
      (string-should-indent input/indent-hash/hang
                            exp/indent-hash/hang))))

;; 3 < 4, so close brace is at 1
(enh-deftest enh-ruby-indent-hash/deep/hang/bil-3 ()
  (with-deep-indent t
    (with-bounce-and-hang nil 3 nil
      (string-should-indent input/indent-hash/hang
                            "\nc = {\n   a: a,\n   b: b,\n   c: c\n}"))))

;; 8 > 4, so close brace is at 4
(enh-deftest enh-ruby-indent-hash/deep/hang/bil-8 ()
  (with-deep-indent t
    (with-bounce-and-hang nil 8 nil
      (string-should-indent input/indent-hash/hang
                            "\nc = {\n        a: a,\n        b: b,\n        c: c\n    }"))))

(enh-deftest enh-ruby-indent-hash/deep/trail/def ()
  (with-deep-indent t
    (with-bounce-and-hang nil nil nil
      (string-should-indent input/indent-hash/trail
                            exp/indent-hash/trail))))

(enh-deftest enh-ruby-indent-hash/deep/bounce/trail/def ()
  (with-deep-indent t
    (with-bounce-and-hang t nil nil
      (string-should-indent input/indent-hash/trail
                            exp/indent-hash/trail))))

(enh-deftest enh-ruby-indent-hash/deep/trail/3 ()
  (with-deep-indent t
    (with-bounce-and-hang nil 3 8
      (string-should-indent input/indent-hash/trail
                            exp/indent-hash/trail/8))))

(enh-deftest enh-ruby-indent-hash/deep/bounce/trail/3 ()
  (with-deep-indent t
    (with-bounce-and-hang t 3 8
      (string-should-indent input/indent-hash/trail
                            exp/indent-hash/trail/8))))

(enh-deftest enh-ruby-indent-hash/deep/trail/8 ()
  (with-deep-indent t
    (with-bounce-and-hang nil 8 8
      (string-should-indent input/indent-hash/trail
                            exp/indent-hash/trail/8))))

(enh-deftest enh-ruby-indent-hash/deep/bounce/trail/8 ()
  (with-deep-indent t
    (with-bounce-and-hang t 8 8
      (string-should-indent input/indent-hash/trail
                            exp/indent-hash/trail/8))))

(enh-deftest enh-ruby-indent-bug/90/a ()
  (string-should-indent-like-ruby "aa.bb(:a => 1,\n      :b => 2,\n      :c => 3)\n"
                                  'deep))

(enh-deftest enh-ruby-indent-bug/90/b ()
  (string-should-indent-like-ruby "literal_array = [\n  :a,\n  :b,\n  :c\n]\n"))

(enh-deftest enh-ruby-indent-hash-after-cmd ()
  (with-deep-indent nil
    (string-should-indent "x\n{\na: a,\nb: b\n}"
                          "x\n{\n  a: a,\n  b: b\n}")))

(enh-deftest enh-ruby-indent-hash-after-cmd/deep ()
  (with-deep-indent t
    (string-should-indent "x\n{\na: a,\nb: b\n}"
                          "x\n{\n  a: a,\n  b: b\n}")))

(enh-deftest enh-ruby-indent-hash-after-cmd/ruby ()
  (string-should-indent-like-ruby "x\n{\na: a,\nb: b\n}"))

(enh-deftest enh-ruby-indent-if-in-assignment ()
  (with-deep-indent nil
    (string-should-indent "foo = if bar\nx\nelse\ny\nend\n"
                          "foo = if bar\n  x\nelse\n  y\nend\n")))

(enh-deftest enh-ruby-indent-if-in-assignment/deep ()
  (with-deep-indent t
    (string-should-indent "foo = if bar\nx\nelse\ny\nend\n"
                          "foo = if bar\n        x\n      else\n        y\n      end\n")))

(enh-deftest enh-ruby-indent-leading-dots ()
  (string-should-indent "d.e\n.f\n"
                        "d.e\n  .f\n"))

(enh-deftest enh-ruby-indent-leading-dots-cvar ()
  (string-should-indent "@@b\n.c\n.d\n"
                        "@@b\n  .c\n  .d\n"))

(enh-deftest enh-ruby-indent-leading-dots-cvar/ruby ()
  (string-should-indent-like-ruby "@@b\n.c\n.d\n"))

(enh-deftest enh-ruby-indent-leading-dots-gvar ()
  (string-should-indent "$b\n.c\n.d\n"
                        "$b\n  .c\n  .d\n"))

(enh-deftest enh-ruby-indent-leading-dots-gvar/ruby ()
  (string-should-indent-like-ruby "$b\n.c\n.d\n"))

(enh-deftest enh-ruby-indent-leading-dots-ident ()
  (string-should-indent "b\n.c\n.d\n"
                        "b\n  .c\n  .d\n"))

(enh-deftest enh-ruby-indent-leading-dots-ident/ruby ()
  (string-should-indent-like-ruby "b\n.c\n.d\n"))

(enh-deftest enh-ruby-indent-leading-dots-ivar ()
  (string-should-indent "@b\n.c\n.d\n"
                        "@b\n  .c\n  .d\n"))

(enh-deftest enh-ruby-indent-leading-dots-ivar/ruby ()
  (string-should-indent-like-ruby "@b\n.c\n.d\n"))

(enh-deftest enh-ruby-indent-leading-dots-with-block ()
  (string-should-indent "a\n.b {}\n.c\n"
                        "a\n  .b {}\n  .c\n"))

(enh-deftest enh-ruby-indent-leading-dots-with-block/ruby ()
  (string-should-indent-like-ruby "a\n.b {}\n.c\n"))

(enh-deftest enh-ruby-indent-leading-dots-with-comment ()
  (string-should-indent "a\n.b # comment\n.c\n"
                        "a\n  .b # comment\n  .c\n"))

(enh-deftest enh-ruby-indent-leading-dots-with-comment/ruby ()
  (string-should-indent-like-ruby "a\n.b # comment\n.c\n"))

(enh-deftest enh-ruby-indent-leading-dots/ruby ()
  (string-should-indent-like-ruby "d.e\n.f\n"))

(enh-deftest enh-ruby-indent-leading-dots-with-arguments-and-newlines ()
  :expected-result :failed
  (string-should-indent "\na\n.b(\nc\n)\n.d\n\ne"
                        "\na\n  .b(\n    c\n  )\n  .d\n\ne"))

(enh-deftest enh-ruby-indent-leading-dots-with-block-and-newlines ()
  :expected-result :failed
  (string-should-indent "\na\n.b do\nc\nend\n.d\n\ne"
                        "\na\n  .b do\n    c\n  end\n  .d\n\ne"))

(enh-deftest enh-ruby-indent-leading-dots-with-brackets-and-newlines ()
  :expected-result :failed
  (string-should-indent "\na\n.b {\nc\n}\n.d\n\ne"
                        "\na\n  .b {\n    c\n  }\n  .d\n\ne"))

(enh-deftest enh-ruby-indent-not-on-eol-opening/deep ()
  (with-deep-indent t
   (string-should-indent "\nfoo(:bar,\n:baz)\nfoo(\n:bar,\n:baz,\n)\n[:foo,\n:bar]\n[\n:foo,\n:bar\n]"
                         "\nfoo(:bar,\n    :baz)\nfoo(\n  :bar,\n  :baz,\n)\n[:foo,\n :bar]\n[\n  :foo,\n  :bar\n]")))

(enh-deftest enh-ruby-indent-pct-w-array ()
  (with-deep-indent nil
    (string-should-indent "words = %w[\na\nb\n]\n"
                          "words = %w[\n  a\n  b\n]\n")))

(enh-deftest enh-ruby-indent-pct-w-array/deep ()
  (with-deep-indent t
    (with-bounce-and-hang nil nil nil
     (string-should-indent "\nwords = %w[a\nb\nc\n]\n"
                           "\nwords = %w[a\n           b\n           c\n          ]\n"))))

;; NO! ruby-mode refuses to indent %w at all
;; words = %w[ a
;; b
;; c
;; ]
;;
;; vs enh-ruby-mode:
;;
;; words = %w[ a
;;   b
;;   c
;; ]
;;
;; and w/ deep-indent-paren t:
;; words = %w[ a
;;             b
;;             c
;;           ]
;;
;; (enh-deftest enh-ruby-indent-pct-w-array/ruby ()
;;   (string-should-indent-like-ruby "words = %w[ a\nb\nc\n]\n"))

(enh-deftest enh-ruby-indent-trailing-dots ()
  (string-should-indent "a.b.\nc\n"
                        "a.b.\n  c\n"))

(enh-deftest enh-ruby-indent-trailing-dots/ruby ()
  (string-should-indent-like-ruby "a.b.\nc\n"))

;;; indent-for-tab-command -- seems different than indent-region in some places

(enh-deftest enh-ruby-beginning-of-block ()
  (with-temp-enh-rb-string
   "RSpec.describe Foo do\n  it 'bar' do\n    HERE\n  end\nend"

   (search-forward "HERE")

   (enh-ruby-beginning-of-block)
   (line-should-equal "  it 'bar' do")

   (enh-ruby-beginning-of-block)
   (line-should-equal "RSpec.describe Foo do")

   (enh-ruby-beginning-of-block)
   (line-should-equal "RSpec.describe Foo do")))

(enh-deftest enh-ruby-indent-for-tab-heredocs/off ()
  (with-temp-enh-rb-string
   "meth <<-DONE\n  a b c\nd e f\nDONE\n"

   (search-forward "d e f")
   (move-beginning-of-line nil)
   (let ((enh-ruby-preserve-indent-in-heredocs nil))
     (indent-for-tab-command)           ; hitting TAB char
     (buffer-should-equal "meth <<-DONE\n  a b c\nd e f\nDONE\n"))))

(enh-deftest enh-ruby-indent-for-tab-heredocs/on ()
  (with-temp-enh-rb-string
   "meth <<-DONE\n  a b c\nd e f\nDONE\n"

   (search-forward "d e f")
   (move-beginning-of-line nil)
   (let ((enh-ruby-preserve-indent-in-heredocs t))
     (indent-for-tab-command)           ; hitting TAB char
     (buffer-should-equal "meth <<-DONE\n  a b c\n  d e f\nDONE\n"))))

(enh-deftest enh-ruby-indent-for-tab-heredocs/unset ()
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

(enh-deftest enh-ruby-toggle-block/both ()
  (with-temp-enh-rb-string
   "7.times { |i|\n  puts \"number #{i+1}\"\n}\n"

   (toggle-to-do)
   (toggle-to-brace)))

(enh-deftest enh-ruby-toggle-block/brace ()
  :expected-result t ; https://github.com/zenspider/enhanced-ruby-mode/issues/132
  (with-temp-enh-rb-string
   "7.times { |i|\n  puts \"number #{i+1}\"\n}\n"

   (toggle-to-do)))

(enh-deftest enh-ruby-toggle-block/do ()
  (with-temp-enh-rb-string
   "7.times do |i|\n  puts \"number #{i+1}\"\nend\n"

   (toggle-to-brace)))

(enh-deftest enh-ruby-paren-mode-if/open ()
  (should-show-parens
   "
G|ifG foo
  bar
GendG"))

(enh-deftest enh-ruby-paren-mode-if/close ()
  (should-show-parens
   "
GifG foo
  bar
Gend|G"))

(enh-deftest enh-ruby-paren-mode-if/mismatch ()
  (should-show-parens
   "
R|ifR foo
  bar
R}R"))

(enh-deftest enh-ruby-paren-mode-while-do/open ()
  (should-show-parens
   "
G|whileG foo do
  if bar
    baz
  end
GendG"))

(enh-deftest enh-ruby-paren-mode-while-do/close ()
  (should-show-parens
   "
GwhileG foo do
  if bar
    baz
  end
Gend|G"))

(enh-deftest enh-ruby-paren-mode-while-do/mismatch ()
  (should-show-parens
   "
R|whileR foo do
  if bar
    baz
  end
RR"))

(enh-deftest enh-ruby-paren-mode-begin-end ()
  (should-show-parens
   "
G|beginG
  foo
rescue
GendG"))

(enh-deftest enh-ruby-paren-mode-if-dont-show ()
  "point is not in right spot to highlight pairs so nothing
should be tagged"
  (should-show-parens
   "
i|f foo
  bar
end")
  (should-show-parens
   "
if| foo
  bar
end")
  (should-show-parens
   "
if foo
  bar
en|d")
  (should-show-parens
   "
if foo
  bar
e|nd"))

(enh-deftest enh-ruby-paren-mode-delegate ()
  "delegate braces to show-paren-data-function (i.e. don't
highlight anything)"
  (should-show-parens
   "foo.map G|{G there G}G"))
