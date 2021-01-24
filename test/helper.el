(require 'ert)
(require 'ert-x)
(require 'paren)                        ; for show-paren tests & helper
(eval-and-compile
  (add-to-list 'load-path (file-name-directory (directory-file-name default-directory))))
(require 'enh-ruby-mode)

;; I hate this so much... Shuts up "Indenting region..." output
(defun make-progress-reporter (&rest ignored) nil)

(defvar enh-tests '())

;; turns out I had a duplicate test and it was driving me crazy. This is my fix.
(defmacro enh-deftest (name &rest rest)
  (if (memq name enh-tests)
      (error "Duplicate test name! %S" name)
    (setq enh-tests (cons name enh-tests))
    `(ert-deftest ,name ,@rest)))
(put 'enh-deftest 'lisp-indent-function 'defun)

(defmacro with-temp-enh-rb-string (str &rest body)
  `(with-temp-buffer
     (insert ,str)
     (enh-ruby-mode)
     (erm-wait-for-parse)
     (font-lock-ensure)
     (goto-char (point-min))
     (progn ,@body)))
(put 'with-temp-enh-rb-string 'lisp-indent-function 1)

(defmacro with-temp-ruby-string (str &rest body)
  `(with-temp-buffer
     (insert ,str)
     (ruby-mode)
     (font-lock-ensure)
     (goto-char (point-min))
     (progn ,@body)))

(defmacro with-deep-indent (deep? &rest body)
  `(let ((enh-ruby-deep-indent-construct ,deep?) ; def / if
         (enh-ruby-deep-indent-paren ,deep?))    ; arrays / hashes
     ,@body))
(put 'with-deep-indent 'lisp-indent-function 1)

(defun buffer-string-plain ()
  (buffer-substring-no-properties (point-min) (point-max)))

(defun string-plain (s)
  (substring-no-properties s))

(defun string-should-indent (ruby exp)
  (let ((act (with-temp-enh-rb-string ruby (ert-buffer-string-reindented))))
   (should (equal exp (string-plain act)))))

(defun string-should-indent-like-ruby (ruby &optional deep?)
  (with-deep-indent deep?
    (let ((exp (with-temp-ruby-string   ruby (ert-buffer-string-reindented)))
          (act (with-temp-enh-rb-string ruby (ert-buffer-string-reindented))))
      (should (equal (string-plain exp) (string-plain act))))))

(defun buffer-should-equal (exp)
  (should (equal exp (buffer-string-plain))))

(defun rest-of-line-should-equal (exp)
  (should (equal exp (rest-of-line))))

(defun line-should-equal (exp)
  (should (equal exp (all-of-line))))

(defun all-of-line ()
  (save-excursion
    (move-beginning-of-line nil)
    (let ((start (point)))
      (end-of-line)
      (buffer-substring-no-properties start (point)))))

(defun rest-of-line ()
  (save-excursion
   (let ((start (point)))
     (end-of-line)
     (buffer-substring-no-properties start (point)))))

(defun should-show-parens (contents)
  "CONTENTS is a template specifying expected paren highlighting.
GfooG means expect foo be green (matching parens), RfooR means
red (mismatched parens), and | is point. No G/R tags means expect
no erm highlighting (i.e. delgate to normal paren-mode)"
  (with-temp-buffer
    (insert contents)
    (goto-char (point-min))
    (let ((case-fold-search nil) (tags ()) point-pos mismatch)
      (while (re-search-forward "[GR|]" nil t)
        (let ((found-char (char-before)))
          (backward-delete-char 1)
          (cond
           ((char-equal found-char ?G) (push (point) tags))
           ((char-equal found-char ?R) (progn (push (point) tags) (setq mismatch t)))
           ((char-equal found-char ?|) (setq point-pos (point))))))
      (setq tags (nreverse tags))
      (when (and tags (< (abs (- point-pos (nth 3 tags))) (abs (- point-pos (car tags)))))
        (setq tags (list (nth 2 tags) (nth 3 tags) (nth 0 tags) (nth 1 tags))))
      (setq contents (buffer-substring (point-min) (point-max)))
      (with-temp-enh-rb-string
       contents
       (goto-char point-pos)
       (should
        (equal
         (erm-show-paren-data-function)
         (if tags (append tags `(,mismatch)) nil)))))))
