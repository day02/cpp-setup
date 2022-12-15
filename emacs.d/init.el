(require 'package)
(add-to-list 'package-archives
         '("melpa" . "http://melpa.org/packages/") t)

(package-initialize)

(when (not package-archive-contents)
    (package-refresh-contents))

(unless (package-installed-p 'use-package)
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t)

(add-to-list 'load-path "~/.emacs.d/custom")

(require 'setup-general)
(if (version< emacs-version "24.4")
    (require 'setup-ivy-counsel)
  (require 'setup-helm)
  (require 'setup-helm-gtags))
;; (require 'setup-ggtags)
(require 'setup-cedet)
(require 'setup-editing)

;; function-args
;; (require 'function-args)
;; (fa-config-default)
;; (define-key c-mode-map  [(tab)] 'company-complete)
;; (define-key c++-mode-map  [(tab)] 'company-complete)
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages
   '(flycheck-clang-tidy flycheck magit-annex magit ztree clang-format yasnippet-snippets zygospore helm-gtags helm yasnippet ws-butler volatile-highlights use-package undo-tree iedit dtrt-indent counsel-projectile company clean-aindent-mode anzu))
 '(safe-local-variable-values '((company-clang-arguments "-I/usr/include/c++/11/"))))

(global-set-key (kbd "<C-up>") 'shrink-window)
(global-set-key (kbd "<C-down>") 'enlarge-window)
(global-set-key (kbd "<C-left>") 'shrink-window-horizontally)
(global-set-key (kbd "<C-right>") 'enlarge-window-horizontally)
(global-set-key (kbd "<f6>") 'helm-gtags-create-tags)
(global-set-key (kbd "<f7>") 'ansi-term)
(global-set-key (kbd "<f8>") 'grep)
(global-set-key (kbd "<f9>") 'gud-gdb)
(global-set-key (kbd "C-x C-f") 'helm-find-files)

;; Stop creating ~ files
(setq make-backup-files nil)

(setq compile-command "bash -i -c osq-mk")
(put 'upcase-region 'disabled nil)
(setq grep-command "grep --color -nriH -e ")
(add-hook 'prog-mode-hook 'display-line-numbers-mode)
(customize-set-variable 'helm-ff-lynx-style-map t)
(with-eval-after-load 'cc-mode
  (fset 'c-indent-region 'clang-format-region))
;; helm-find-files tab open directory
(define-key helm-find-files-map (kbd "C-i") 'helm-ff-TAB)
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
(setq tags-table-list
      '("/home/uraina/code"))
