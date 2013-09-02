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
  :expected-result :failed
  (with-temp-enh-rb-buffer
   "test/rubytest-file.rb"
   (search-forward " word_")
   (move-end-of-line nil)
   (enh-ruby-backward-sexp 2)
   (should (looking-at "%_string"))))

(ert-deftest enh-ruby-up-sexp-test ()
  (with-temp-enh-rb-buffer
   "test/rubytest-file.rb"
   (goto-char (point-min))
   (search-forward "test")
   (enh-ruby-up-sexp)
   (should (looking-at "def foo"))))
