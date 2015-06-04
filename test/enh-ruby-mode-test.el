(load-file "test/helper.el")
(load-file "enh-ruby-mode.el")

;; In batch mode, face-attribute returns 'unspecified,
;; and it causes wrong-number-of-arguments errors.
;; This is a workaround for it.
(defun erm-darken-color (name)
  (let ((attr (face-attribute name :foreground)))
    (unless (equal attr 'unspecified)
      (color-darken-name attr 20)
      "#000000")))

(ert-deftest enh-ruby-backward-sexp-test ()
  (with-temp-enh-rb-buffer
   "test/rubytest-file.rb"
   (search-forward "def backward_sexp")
   (move-beginning-of-line nil)
   (enh-ruby-backward-sexp 1)
   (should (looking-at "def foo"))))

(ert-deftest enh-ruby-backward-sexp-test-inner ()
  :expected-result :failed
  (with-temp-enh-rb-buffer
   "test/rubytest-file.rb"
   (search-forward " word_")
   (move-end-of-line nil)
   (enh-ruby-backward-sexp 2)
   (should (looking-at "%_string"))))

(ert-deftest enh-ruby-forward-sexp-test ()
  (with-temp-enh-rb-buffer
   "test/rubytest-file.rb"
   (search-forward "def foo")
   (move-beginning-of-line nil)
   (enh-ruby-forward-sexp 1)
   (should (looking-at "\n\ndef backward_sexp"))))

(ert-deftest enh-ruby-up-sexp-test ()
  (with-temp-enh-rb-buffer
   "test/rubytest-file.rb"
   (search-forward "test1_")
   (enh-ruby-up-sexp)
   (should (looking-at "def foo"))))

(ert-deftest enh-ruby-indent-trailing-dots ()
  (with-temp-enh-rb-buffer
   "test/rubytest-indent.rb"
   (indent-region (point-min) (point-max))
   (search-forward "a.b.")
   (should (looking-at "\n  c"))))

(ert-deftest enh-ruby-indent-leading-dots ()
  (with-temp-enh-rb-buffer
   "test/rubytest-indent.rb"
   (indent-region (point-min) (point-max))
   (search-forward "d.e")
   (should (looking-at "\n  .f"))))

(ert-deftest enh-ruby-indent-pct-w-array ()
  (with-temp-enh-rb-buffer
   "test/rubytest-indent.rb"
   (indent-region (point-min) (point-max))
   (search-forward "words1 = %w[\n")
   (should (looking-at "          moo\n         ]\n"))))

(ert-deftest enh-ruby-indent-array-of-strings ()
  (with-temp-enh-rb-buffer
   "test/rubytest-indent.rb"
   (indent-region (point-min) (point-max))
   (search-forward "words2 = [\n")
   (should (looking-at "          'moo'\n         ]\n"))))
