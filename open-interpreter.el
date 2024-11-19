;;; open-interpreter.el --- Interface to interpreter CLI -*- lexical-binding: t -*-

;; Author: Kang Tu
;; Version: 0.1.0
;; Package-Requires: ((emacs "25.1") (helm "3.0"))
;; Keywords: processes
;; URL: https://github.com/tninja/open-interpreter-mode

;;; Commentary:
;; Provides an interface to the interpreter CLI application

;;; Code:
(require 'comint)
(require 'helm)

(defgroup open-interpreter nil
  "Interface to interpreter CLI."
  :group 'external)

(defcustom open-interpreter-program "interpreter"
  "Name of the interpreter executable."
  :type 'string
  :group 'open-interpreter)

(defcustom open-interpreter-arguments '("-y")
  "List of command line arguments to pass to interpreter."
  :type '(repeat string)
  :group 'open-interpreter)

(defcustom open-interpreter-prompt-suffix nil
  "Suffix to append to input before sending to interpreter.
If non-nil, will be appended with \". \" prefix."
  :type '(choice (const :tag "None" nil)
                (string :tag "Suffix"))
  :group 'open-interpreter)

(defvar open-interpreter-buffer-name "*open-interpreter*"
  "Name of the interpreter buffer.")


;;;###autoload
(defun open-interpreter ()
  "Run interpreter in a buffer."
  (interactive)
  (let* ((buffer (get-buffer-create open-interpreter-buffer-name))
         (proc (get-buffer-process buffer)))
    (unless (and proc (process-live-p proc))
      (with-current-buffer buffer
        (apply 'make-comint-in-buffer "interpreter" buffer
               open-interpreter-program nil open-interpreter-arguments)
        (comint-mode)
      ))
    (pop-to-buffer buffer)))

;;;###autoload
(defun open-interpreter-switch-to-buffer ()
  "Switch to the interpreter buffer if it exists."
  (interactive)
  (if (get-buffer open-interpreter-buffer-name)
      (pop-to-buffer open-interpreter-buffer-name)
    (message "No interpreter buffer exists. Use M-x open-interpreter to start one.")))

(defun open-interpreter-helm-read-string-with-history (prompt history-file-name)
  "Read a string with Helm completion using specified history file.
PROMPT is the prompt string.
HISTORY-FILE-NAME is the base name for history file."
  ;; Load history from file
  (let* ((history-file (expand-file-name history-file-name user-emacs-directory))
         (history (when (file-exists-p history-file)
                   (with-temp-buffer
                     (insert-file-contents history-file)
                     (delete-dups (read (buffer-string))))))
         ;; Read input with helm
         (input (helm-comp-read
                prompt
                history
                :must-match nil
                :name "Helm Read String"
                :fuzzy t)))
    ;; Add to history if non-empty and save
    (unless (string-empty-p input)
      (push input history)
      (with-temp-file history-file
        (let ((history-entries (cl-subseq history
                                         0 (min (length history)
                                              1000))))  ; Keep last 1000 entries
          (insert (prin1-to-string history-entries)))))
    input))

(defun open-interpreter-send-input (input)
  "Send INPUT to the interpreter buffer and switch to it."
  (let* ((newline-del (replace-regexp-in-string "\n" " " input))
         (newline-tail-with-suffix (if open-interpreter-prompt-suffix
                                       (concat newline-del ". " open-interpreter-prompt-suffix "\n")
                                       (concat newline-del "\n"))))
    (with-current-buffer open-interpreter-buffer-name
      (goto-char (point-max))
      (insert newline-tail-with-suffix)
      (comint-send-input))
    (open-interpreter-switch-to-buffer)))

(defun open-interpreter-chat-helm ()
  "Read a string with Helm completion, showing historical inputs."
  (interactive)
  (let* ((prompt "Chat with open-interpreter: ")
         (input (open-interpreter-helm-read-string-with-history
                 prompt "open-interpreter-helm-read-string-history.el")))
    (unless (get-buffer open-interpreter-buffer-name)
      (open-interpreter))
    (let ((proc (get-buffer-process open-interpreter-buffer-name)))
      (if (and proc (process-live-p proc))
          (open-interpreter-send-input input)
        (message "Interpreter process not running. Please restart it.")))))

(defun open-interpreter-action ()
  "Send text to interpreter.
If region is active, send selected text.
Otherwise use helm to get input.
Create interpreter process if it doesn't exist."
  (interactive)
  (if (not (get-buffer open-interpreter-buffer-name))
      (open-interpreter)
    (let ((proc (get-buffer-process open-interpreter-buffer-name)))
      (if (and proc (process-live-p proc))
          (if (use-region-p)
              (let ((text (buffer-substring-no-properties
                          (region-beginning) (region-end))))
                (open-interpreter-send-input text))
            (open-interpreter-chat-helm))
        (message "Interpreter process not running. Please restart it.")))))

;; (global-set-key (kbd "C-c i") 'open-interpreter-action)

(provide 'open-interpreter)
;;; open-interpreter.el ends here
