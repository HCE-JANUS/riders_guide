;;; init.el --- Emacs configuration -*- lexical-binding: t; -*-

;;; Package Management

(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

;;; UI / Appearance

(setq inhibit-startup-message t
      visible-bell t)
(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(load-theme 'modus-vivendi t)
(setq display-line-numbers-type 'relative)
(global-display-line-numbers-mode)
(global-hl-line-mode 1)

;;; Built-in Behavior

(global-visual-line-mode 1)
(recentf-mode 1)
(setq history-length 25)
(save-place-mode 1)
(setq dired-dwim-target t) ;; suggest other dired buffer as copy/move target

;;; Tree-sitter
;; Emacs 30 ships treesit as a built-in; treesit-auto handles grammar downloads.
;; On first visit to a .py file it will prompt to compile the Python grammar
;; (requires gcc and git in WSL — run: which gcc git).

(use-package treesit-auto
  :ensure t
  :custom
  (treesit-auto-install 'prompt) ;; ask before compiling each grammar
  :config
  (treesit-auto-add-to-auto-mode-alist 'all) ;; remap python-mode → python-ts-mode, etc.
  (global-treesit-auto-mode))
  (add-to-list 'major-mode-remap-alist '(python-mode . python-ts-mode))
;; Teach project.el to recognize Python project roots even without .git
(setq project-vc-extra-root-markers
      '("pyrightconfig.json" "pyproject.toml" "setup.py" "setup.cfg"))

;;; Completion Framework (Vertico + friends)

(use-package vertico
  :custom
  (vertico-scroll-margin 0)
  (vertico-count 20)
  (vertico-resize t)
  (vertico-cycle t)
  :init
  (vertico-mode))

;; Persist minibuffer history so Vertico can sort by frequency
(use-package savehist
  :init
  (savehist-mode))

;; Minibuffer settings
(use-package emacs
  :custom
  (context-menu-mode t)
  (enable-recursive-minibuffers t)
  ;; Hide M-x commands that don't apply to the current mode
  (read-extended-command-predicate #'command-completion-default-include-p)
  (minibuffer-prompt-properties
   '(read-only t cursor-intangible t face minibuffer-prompt)))

;; Rich annotations alongside minibuffer candidates
(use-package marginalia
  :bind (:map minibuffer-local-map
         ("M-A" . marginalia-cycle))
  :init
  (marginalia-mode))

;; Orderless completion style (space-separated tokens, any order)
(use-package orderless
  :ensure t
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides
   '((file       (styles partial-completion))
     ;; Use orderless for LSP completions in corfu popup
     (eglot      (styles orderless basic))
     (eglot-capf (styles orderless basic))))
  (completion-pcm-leading-wildcard t))

;; Consult: enhanced search and navigation commands
(use-package consult
  :ensure t
  :bind (("M-s M-g" . consult-grep)
         ("M-s M-f" . consult-find)
         ("M-s M-o" . consult-outline)
         ("M-s M-l" . consult-line)
         ("M-s M-b" . consult-buffer)
         ("M-s M-d" . consult-flymake)        ;; browse linting diagnostics
         ("M-s M-p" . consult-project-buffer))) ;; buffers in current project

;; Embark: contextual actions on minibuffer candidates
(use-package embark
  :ensure t
  :bind (("C-." . embark-act)
         :map minibuffer-local-map
         ("C-c C-c" . embark-collect)
         ("C-c C-e" . embark-export)))

(use-package embark-consult
  :ensure t)

;; Editable grep results (pairs well with consult-grep)
(use-package wgrep
  :ensure t
  :bind (:map grep-mode-map
         ("e"       . wgrep-change-to-wgrep-mode)
         ("C-x C-q" . wgrep-change-to-wgrep-mode)
         ("C-c C-c" . wgrep-finish-edit)))

;; Corfu: in-buffer completion popup
;; Consult handles search/navigation; corfu handles as-you-type code completion.
;; Both coexist — they operate at different interaction layers.
(use-package corfu
  :ensure t
  :custom
  (corfu-auto t)          ;; trigger popup automatically
  (corfu-auto-delay 0.2)
  (corfu-auto-prefix 2)   ;; start after 2 characters
  (corfu-cycle t)
  (corfu-quit-no-match t)
  :init
  (global-corfu-mode))

;; Cape: extra completion-at-point sources that feed into corfu
(use-package cape
  :ensure t
  :init
  ;; Add file path and buffer-word completion inside Python buffers
  (add-hook 'python-ts-mode-hook
            (lambda ()
              (add-to-list 'completion-at-point-functions #'cape-file)
              (add-to-list 'completion-at-point-functions #'cape-dabbrev t))))

;;; Org Mode

(use-package org-recur
  :hook ((org-mode        . org-recur-mode)
         (org-agenda-mode . org-recur-agenda-mode))
  :demand t
  :config
  (define-key org-recur-mode-map        (kbd "C-c d") 'org-recur-finish)
  (define-key org-recur-agenda-mode-map (kbd "d")     'org-recur-finish)
  (define-key org-recur-agenda-mode-map (kbd "C-c d") 'org-recur-finish)
  (setq org-recur-finish-done    t
        org-recur-finish-archive t))

;; Refresh all open agenda buffers after rescheduling
(defun org-agenda-refresh ()
  "Refresh all `org-agenda' buffers."
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (derived-mode-p 'org-agenda-mode)
        (org-agenda-maybe-redo)))))

(defadvice org-schedule (after refresh-agenda activate)
  "Refresh org-agenda after scheduling a task."
  (org-agenda-refresh))

(setq org-log-done               'time  ;; record completion timestamp
      org-log-redeadline         nil
      org-log-reschedule         nil
      org-read-date-prefer-future 'time)

(setq org-todo-keywords
      '((sequence "TODO" "IN-PROGRESS" "DONE" "WAITING" "DELEGATED" "CANCELED")))

(setq org-tag-alist
      '(("@work" . ?w) ("@home" . ?h) ("project" . ?p)
        ("recurring" . ?r) ("janus-schedule" . ?j)))

;; org-tempo: <s TAB → #+begin_src ... structure templates
(require 'org-tempo)
(add-to-list 'org-modules 'org-tempo)

;; Pretty Unicode bullets for org headings
(use-package org-bullets
  :ensure t
  :hook (org-mode . org-bullets-mode))

;;; Elfeed — RSS/Atom feed reader

(use-package elfeed
  :ensure t
  :bind ("C-c e" . elfeed)
  :config
  (setq elfeed-feeds
        '(;; Emacs
          ("https://planet.emacslife.com/atom.xml"        emacs)
          ("https://sachachua.com/blog/category/emacs/feed/" emacs)
          ("https://protesilaos.com/feeds/advice.xml"     emacs)
          ("https://www.masteringemacs.org/feed"          emacs)
          ;; PostgreSQL & database architecture
          ("https://www.depesz.com/feed/"                 postgres)
          ("https://postgresweekly.com/rss/"              postgres)
          ("https://www.citusdata.com/blog/rss.xml"       postgres database)
          ("https://use-the-index-luke.com/blog/feed"     database)
          ;; Python data science
          ("https://feeds.feedburner.com/PythonSoftwareFoundationNews" python)
          ("https://realpython.com/atom.xml"              python)
          ("https://pythonspeed.com/atom.xml"             python datasci)
          ("https://www.fast.ai/atom.xml"                 python datasci)
          ;; FastAPI / web backend
          ("https://fastapi.tiangolo.com/release-notes/feed.xml" python fastapi)
          ("https://bytes.dev/rss.xml"                    python fastapi)
          ;; R / statistics
          ("https://www.r-bloggers.com/feed/"             r stats)
          ("https://simplystatistics.org/index.xml"       r stats))))

;;; External Tools

;; Python virtual environment support.
;; After switching venvs, eglot reconnects so basedpyright sees the new interpreter.
(use-package pyvenv
  :ensure t
  :config
  (pyvenv-mode 1)
  (add-hook 'pyvenv-post-activate-hooks
            (lambda ()
              (when (and (fboundp 'eglot-current-server) (eglot-current-server))
                (call-interactively #'eglot-reconnect))))
  (add-hook 'pyvenv-post-deactivate-hooks
            (lambda ()
              (when (and (fboundp 'eglot-current-server) (eglot-current-server))
                (call-interactively #'eglot-reconnect)))))

;; Git interface; always rebase on pull for the Riders Guide repo
(use-package magit
  :ensure t
  :bind ("C-x g" . magit-status)
  :config
  (setq magit-pull-arguments '("--rebase"))
  (setq magit-repository-directories
        '(("C:/Users/klooper/Documents/Riders_Guide" . 0))))

;; Terminal emulator inside Emacs (used for Claude Code)
(use-package eat
  :ensure t
  :config
  (setq eat-minimum-latency 0.002
        eat-maximum-latency 0.02))

;;; Python Development
;; Prerequisites (run once in WSL shell):
;;   pip3 install ruff debugpy
;; basedpyright is already installed via npm.

;; eglot: built-in LSP client.  Provides go-to-definition, hover docs,
;; completions, and feeds diagnostics to flymake.
(use-package eglot
  :ensure nil ;; built-in
  :config
  ;; Register basedpyright (same CLI interface as pyright)
  (add-to-list 'eglot-server-programs
               '((python-mode python-ts-mode)
                 . ("basedpyright-langserver" "--stdio")))
  (setq eglot-autoshutdown t        ;; shut down server when last buffer closes
        eglot-events-buffer-size 0)) ;; don't log LSP events (reduce noise)

;; consult-eglot: search workspace symbols with consult's incremental interface
(use-package consult-eglot
  :ensure t
  :after (consult eglot)
  :bind (:map eglot-mode-map
         ("M-s M-s" . consult-eglot-symbols)))

;; flymake-ruff: add ruff as a second flymake backend alongside eglot/basedpyright.
;; basedpyright handles type errors; ruff handles style, unused imports, etc.
(use-package flymake-ruff
  :ensure t)

;; Flymake navigation (active whenever eglot or flymake-ruff is running)
(with-eval-after-load 'flymake
  (define-key flymake-mode-map (kbd "M-n") #'flymake-goto-next-error)
  (define-key flymake-mode-map (kbd "M-p") #'flymake-goto-prev-error))

;; Start eglot + flymake-ruff whenever python-ts-mode is active, regardless
;; of how the mode was set (direct call or major-mode-remap-alist remap).
(add-hook 'after-change-major-mode-hook
          (lambda ()
            (when (eq major-mode 'python-ts-mode)
              (eglot-ensure)
              (flymake-ruff-load))))

;; dape: built-in debugger (Emacs 30+), uses Debug Adapter Protocol.
;; Requires: pip3 install debugpy
;; Usage: M-x dape → select debugpy → launches current file.
;; Set breakpoints with C-x C-a b (dape-breakpoint-toggle).
(use-package dape
  :ensure nil ;; built-in in Emacs 30
  :config
  (add-to-list 'dape-configs
               `(debugpy
                 modes (python-ts-mode python-mode)
                 command "python3"
                 command-args ("-m" "debugpy.adapter")
                 :type "python"
                 :request "launch"
                 :program dape-buffer-default
                 :justMyCode t)))

;;; Modeline
(which-function-mode 1)

;;; Python REPL split
;; When opening a Python file, open an inferior Python process in a right split.
;; Only splits if the REPL isn't already visible in the current frame.
(defun my/python-repl-split ()
  "Open Python REPL in a right split if not already visible."
  (unless (get-buffer-window "*Python*")
    (let ((orig (selected-window)))
      (select-window (split-window-right))
      (run-python nil nil nil)
      (select-window orig))))

(add-hook 'python-ts-mode-hook #'my/python-repl-split)
(add-hook 'python-ts-mode-hook #'font-lock-fontify-buffer)

;;; Custom Functions & Keybindings

(defun my/claude ()
  "Open Claude Code in the home working directory."
  (interactive)
  (let ((default-directory "/mnt/c/Users/klooper/"))
    (eat "claude")))

(global-set-key (kbd "C-c a") 'my/claude)

;;; Customize (managed by Emacs — do not edit manually)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(org-agenda-files
   '("C:\\Users\\klooper\\OneDrive - JANUS DEVELOPMENTAL SERVICES, INC\\Documents\\Org\\"))
 '(org-safe-remote-resources '("\\`https://fniessen\\.github\\.io\\(?:/\\|\\'\\)"))
 '(package-selected-packages nil)
 '(warning-suppress-log-types
   '((treesit) (files missing-lexbind-cookie "~/.emacs.d/init.el"))))

(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
