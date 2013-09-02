(require 'ert)

(defmacro with-temp-enh-rb-buffer (path &rest body)
  `(with-temp-buffer
     (insert-file-contents ,path)
     (enh-ruby-mode)
     (erm-wait-for-parse)
     (goto-char (point-min))
     (progn ,@body)))
