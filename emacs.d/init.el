;;; init.el --- Emacs 29.3 C++/Python setup (GUI + modern + light) -*- lexical-binding: t; -*-

;; -------------------------
;; Basics
;; -------------------------
(setq inhibit-startup-message t
      ring-bell-function 'ignore
      make-backup-files nil
      auto-save-default nil
      create-lockfiles nil
      use-short-answers t)

;; Terminal niceties
(xterm-mouse-mode 1)
(global-set-key (kbd "S-<left>")  #'windmove-left)
(global-set-key (kbd "S-<right>") #'windmove-right)
(global-set-key (kbd "S-<up>")    #'windmove-up)
(global-set-key (kbd "S-<down>")  #'windmove-down)

(defun my/smart-beginning-of-line ()
  "Move point to first non-whitespace character or beginning of line."
  (interactive)
  (let ((orig-point (point)))
    (back-to-indentation)
    (when (= orig-point (point))
      (move-beginning-of-line 1))))
(global-set-key (kbd "C-a") #'my/smart-beginning-of-line)

;; UTF-8 everywhere
(set-language-environment "UTF-8")
(set-default-coding-systems 'utf-8-unix)

;; Nice defaults
(add-hook 'prog-mode-hook #'display-line-numbers-mode)
(setq-default indent-tabs-mode nil
              tab-width 4)

;; Compilation
(setq compilation-scroll-output 'first-error)
(add-hook 'prog-mode-hook #'flymake-mode)

;; -------------------------
;; package.el + use-package
;; -------------------------
(require 'package)
(setq package-archives
      '(("gnu"   . "https://elpa.gnu.org/packages/")
        ("melpa" . "https://melpa.org/packages/")))
(package-initialize)

(unless package-archive-contents
  (package-refresh-contents))

(unless (package-installed-p 'use-package)
  (package-install 'use-package))
(require 'use-package)
(setq use-package-always-ensure t)

;; -------------------------
;; Minibuffer (Vertico stack)
;; -------------------------
(use-package vertico
  :init
  (vertico-mode 1)
  :custom
  (vertico-cycle t)
  ;; Helm-like: keep list height stable (don’t shrink when few matches)
  (vertico-count 15)
  (vertico-resize nil)
  (vertico-scroll-margin 2))

(use-package vertico-directory
  :after vertico
  :ensure nil
  :bind (:map vertico-map
              ("<left>"  . vertico-directory-up)
              ("<right>" . vertico-directory-enter)
              ("DEL"     . vertico-directory-delete-char)))

(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-defaults nil)
  ;; Make file completion friendly (partial paths + orderless)
  (completion-category-overrides '((file (styles partial-completion orderless basic)))))

(use-package marginalia
  :init (marginalia-mode 1))

(use-package consult
  :bind (("C-s"   . consult-line)
         ("C-c s" . consult-ripgrep)
         ("C-c b" . consult-buffer)
         ("C-c i" . consult-imenu)
         ("C-c C-f" . consult-find)))

(use-package embark
  :bind (("C-."   . embark-act)
         ("C-h B" . embark-bindings))
  :init (setq prefix-help-command #'embark-prefix-help-command))

(use-package embark-consult
  :after (embark consult))

(use-package undo-tree
  :init
  (global-undo-tree-mode 1)
  :custom
  (undo-tree-history-directory-alist
   '(("." . "~/.emacs.d/undo")))
  (undo-tree-auto-save-history t))

;; -------------------------
;; Project + Git
;; -------------------------
(use-package projectile
  :init (projectile-mode 1)
  :custom (projectile-enable-caching t)
  :bind-keymap ("C-c p" . projectile-command-map))

(use-package magit
  :bind (("C-c g" . magit-status)))

;; -------------------------
;; Completion + snippets
;; -------------------------
(use-package company
  :init (global-company-mode 1)
  :custom
  (company-idle-delay 0.2)
  (company-minimum-prefix-length 1)
  (company-tooltip-align-annotations t)
  :bind (:map company-active-map
              ("<tab>" . company-complete-selection)
              ("TAB"   . company-complete-selection)))

(use-package yasnippet
  :init (yas-global-mode 1))

(use-package yasnippet-snippets
  :after yasnippet)

;; -------------------------
;; Whitespace / indentation helpers
;; -------------------------
(use-package ws-butler
  :hook ((prog-mode text-mode) . ws-butler-mode))

(use-package dtrt-indent
  :init (dtrt-indent-mode 1)
  :custom (dtrt-indent-verbosity 0))

;; -------------------------
;; LSP: Eglot (built-in)
;; -------------------------
(use-package eglot
  :ensure nil
  :commands (eglot eglot-ensure)
  :hook ((c-mode c++-mode python-mode) . eglot-ensure)
  :custom
  (eglot-autoshutdown t)
  (eglot-send-changes-idle-time 0.2))

(with-eval-after-load 'eglot
  (global-set-key (kbd "C-c r") #'eglot-rename))

;; Keep xref defaults: M-. / M-? / M-, unchanged
(setq xref-show-definitions-function #'xref-show-definitions-completing-read
      xref-show-xrefs-function #'xref-show-xrefs-completing-read)

;; -------------------------
;; C / C++
;; -------------------------
(use-package cc-mode
  :ensure nil
  :custom
  (c-default-style "linux")
  (c-basic-offset 4))

(use-package clang-format
  :commands (clang-format-buffer clang-format-region)
  :bind (("C-c f" . clang-format-buffer)))

;; -------------------------
;; Python
;; -------------------------
(use-package pyvenv
  :init (pyvenv-mode 1)
  :config
  (when (file-directory-p (expand-file-name "~/.venv"))
    (pyvenv-activate (expand-file-name "~/.venv"))))

(use-package python
  :ensure nil
  :custom (python-indent-offset 4))

(use-package blacken
  :hook (python-mode . blacken-mode)
  :custom (blacken-line-length 88))

(use-package isortify
  :hook (python-mode . isortify-mode))

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '(python-mode . ("pyright-langserver" "--stdio"))))

(add-hook 'python-mode-hook
          (lambda ()
            (add-hook 'before-save-hook #'blacken-buffer nil t)
            (add-hook 'before-save-hook #'isortify-buffer nil t)))

(when (executable-find "mypy")
  (setenv "MYPY_CACHE_DIR" (expand-file-name "~/.cache/mypy"))
  (message "Set MYPY_CACHE_DIR to %s" (getenv "MYPY_CACHE_DIR")))

;; Handy: show diagnostics list
(global-set-key (kbd "C-c e") #'flymake-show-buffer-diagnostics)

;; -------------------------
;; Dockerfile
;; -------------------------
(setq treesit-language-source-alist
      '((dockerfile "https://github.com/camdencheek/tree-sitter-dockerfile")))
(treesit-install-language-grammar 'dockerfile)

;; Directly associate Dockerfile with tree-sitter mode
(add-to-list 'auto-mode-alist
             '("Dockerfile\\'" . dockerfile-ts-mode))

;; -------------------------
;; vterm: bottom panel + toggle hide/show
;; -------------------------
;; Force vterm to display at bottom
(add-to-list 'display-buffer-alist
             '("^\\*vterm\\*"
               (display-buffer-at-bottom)
               (window-height . 0.30)))

(use-package vterm
  :commands vterm)

(defun my/toggle-vterm ()
  "Toggle *vterm* window at the bottom."
  (interactive)
  (let ((buf (get-buffer "*vterm*")))
    (if (and buf (get-buffer-window buf))
        (delete-window (get-buffer-window buf))
      (vterm))))

(global-set-key (kbd "C-c t") #'my/toggle-vterm)

;; -------------------------
;; Build helper
;; -------------------------
(global-set-key (kbd "<f5>") #'compile)
(global-set-key (kbd "<f7>") 'grep-find)
(winner-mode 1)
(delete-selection-mode 1)

;;; init.el ends here

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages
   '(vterm isortify blacken pyvenv clang-format dtrt-indent ws-butler yasnippet-snippets yasnippet company magit projectile embark-consult embark consult marginalia orderless vertico undo-tree)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
