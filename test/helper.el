(require 'ert)

(defmacro with-temp-enh-rb-string (str &rest body)
  `(with-temp-buffer
     (insert ,str)
     (enh-ruby-mode)
     (erm-wait-for-parse)
     (goto-char (point-min))
     (progn ,@body)))

(defun buffer-string-plain ()
  (buffer-substring-no-properties (point-min) (point-max)))

(defun buffer-should-equal (exp)
  (should (equal exp (buffer-string-plain))))

(defun line-should-equal (exp)
  (should (equal exp (rest-of-line))))

(defun rest-of-line ()
  (save-excursion
   (let ((start (point)))
     (end-of-line)
     (buffer-substring-no-properties start (point)))))
