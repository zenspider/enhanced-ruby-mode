(require 'ert)

;; disable VC-git to speed up
(if (fboundp 'vc-find-file-hook)
    (remove-hook 'find-file-hooks 'vc-find-file-hook))
