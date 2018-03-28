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

(defun buffer-string-plain ()
  (buffer-substring-no-properties (point-min) (point-max)))

(defun string-should-indent (ruby exp)
  (with-temp-enh-rb-string
   ruby

   (should (equal exp (ert-buffer-string-reindented)))))

(defun buffer-should-equal (exp)
  (should (equal exp (buffer-string-plain))))

(defun line-should-equal (exp)
  (should (equal exp (rest-of-line))))

(defun rest-of-line ()
  (save-excursion
   (let ((start (point)))
     (end-of-line)
     (buffer-substring-no-properties start (point)))))
