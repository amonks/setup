;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets.
(setq user-full-name "Andrew Monks"
      user-mail-address "a@monks.co")

;; Doom exposes five (optional) variables for controlling fonts in Doom. Here
;; are the three important ones:
;;
;; + `doom-font'
;; + `doom-variable-pitch-font'
;; + `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;;
;; They all accept either a font-spec, font string ("Input Mono-12"), or xlfd
;; font string. You generally only need these two:
;; (setq doom-font (font-spec :family "monospace" :size 12 :weight 'semi-light)
;;       doom-variable-pitch-font (font-spec :family "sans" :size 13))
(setq doom-font (font-spec :family "Operator Mono Lig" :size 16))

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-gruvbox)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; Here are some additional functions/macros that could help you configure Doom:
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.


;; Enable mouse support in iterm2
(global-set-key [mouse-4] 'scroll-down-line)
(global-set-key [mouse-5] 'scroll-up-line)


;; Disable the `s' binding to evil-snipe. I use `s' too much for substitue.
(remove-hook 'doom-first-input-hook #'evil-snipe-mode)

;; Disable auto-close on parens/quotes/etc
(remove-hook 'doom-first-buffer-hook #'smartparens-global-mode)

;; C-c C-c to evaluate top level form _within_ Rich comment
(setq clojure-toplevel-inside-comment-form t)

;; add graphviz support
(use-package! graphviz-dot-mode)
(use-package! graphql-mode)


;; formatting
(add-hook! 'go-mode-hook
  (setq gofmt-command "goimports")
  (add-hook 'before-save-hook #'lsp-format-buffer nil 'local)
  (add-hook 'before-save-hook #'lsp-organize-imports nil 'local))

(defun use-prettier (parser)
  "use prettierjs with the given parser"
  (message "using prettier with: '%s'" parser)
  (make-local-variable 'prettier-js-args)
  (setq prettier-js-args `("--parser" ,parser))
  (prettier-js-mode))

(use-package! prettier-js)
(add-hook! 'mhtml-mode-hook (use-prettier "go-template"))
(add-hook! 'typescript-mode-hook (use-prettier "typescript"))
(add-hook! 'typescript-tsx-mode-hook (use-prettier "typescript"))
(add-hook! 'css-mode-hook (use-prettier "css"))


;; vim-vinegar
(define-key evil-normal-state-map (kbd "-") 'dired-jump)

