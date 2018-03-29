(require 'ert)
(require 'ert-x)

;; I hate this so much... Shuts up "Indenting region..." output
(defun make-progress-reporter (&rest ignored) nil)

(defmacro with-temp-enh-rb-string (str &rest body)
  `(with-temp-buffer
     (insert ,str)
     (enh-ruby-mode)
     (erm-wait-for-parse)
     (font-lock-fontify-buffer)
     (goto-char (point-min))
     (progn ,@body)))

(defmacro with-temp-ruby-string (str &rest body)
  `(with-temp-buffer
     (insert ,str)
     (ruby-mode)
     (font-lock-fontify-buffer)
     (goto-char (point-min))
     (progn ,@body)))

(defmacro with-deep-indent (deep? &rest body)
  `(let ((enh-ruby-deep-indent-construct ,deep?)
        (enh-ruby-deep-indent-paren ,deep?))
     ,@body))
(put 'with-deep-indent 'lisp-indent-function 1)

(defun buffer-string-plain ()
  (buffer-substring-no-properties (point-min) (point-max)))

(defun string-plain (s)
  (substring-no-properties s))

(defun string-should-indent (ruby exp)
  (let ((act (with-temp-enh-rb-string ruby (ert-buffer-string-reindented))))
   (should (equal exp (string-plain act)))))

(defun string-should-indent-like-ruby (ruby)
  (let ((exp (with-temp-ruby-string   ruby (ert-buffer-string-reindented)))
        (act (with-temp-enh-rb-string ruby (ert-buffer-string-reindented))))
    (should (equal (string-plain exp) (string-plain act)))))

(defun buffer-should-equal (exp)
  (should (equal exp (buffer-string-plain))))

(defun line-should-equal (exp)
  (should (equal exp (rest-of-line))))

(defun rest-of-line ()
  (save-excursion
   (let ((start (point)))
     (end-of-line)
     (buffer-substring-no-properties start (point)))))
