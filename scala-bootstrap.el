;;; scala-bootstrap.el --- Installer of Scala tools

;; Author: INA Lintaro <tarao.gnn at gmail.com>
;; URL: https://github.com/tarao/scala-bootstrap-el
;; Version: 0.1
;; Keywords: scala tool

;; This file is NOT part of GNU Emacs.

;;; License:
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Code:

(require 'json)   ;; json-read
(require 'subr-x) ;; string-remove-prefix

(defgroup scala-bootstrap nil
  "Installer of Scala tools"
  :prefix "scala-bootstrap:"
  :group 'convenience)

(defcustom scala-bootstrap:bin-directory
  (expand-file-name "bin" user-emacs-directory)
  "Directory to place installed tools."
  :type 'directory
  :group 'scala-bootstrap)

(defcustom scala-bootstrap:metals-scala-version "2.12"
  "Scala version of Metals."
  :type 'string
  :group 'scala-bootstrap)

(defcustom scala-bootstrap:metals-version nil
  "Metals version to install."
  :type '(choice (const :tag "latest" nil) string)
  :group 'scala-bootstrap)

(defconst scala-bootstrap-metals-artifact-template
  "org.scalameta:metals_%s:%s")
(defconst scala-bootstrap-metals-releases-api
  "https://api.github.com/repos/scalameta/metals/releases/latest")

(defun scala-bootstrap-enable-bin-directory ()
  (let ((dir scala-bootstrap:bin-directory))
    (make-directory dir t)
    (add-to-list 'exec-path dir)
    (unless (member dir (split-string (getenv "PATH") ":" t))
      (setenv "PATH" (concat dir ":" (getenv "PATH"))))))

(defun scala-bootstrap-process-buffer-name (process-name)
  (format "*scala-bootstrap:%s*" process-name))

(defun scala-bootstrap-async-command (name command callback)
  (let* ((buf-name (scala-bootstrap-process-buffer-name name))
         (buf (get-buffer-create buf-name))
         (win (selected-window)))
    (make-process
     :name name
     :buffer buf-name
     :command command
     :stderr buf
     :sentinel `(lambda (proc event)
                  (when (and (eq (process-status proc) 'exit)
                             (= 0 (process-exit-status proc)))
                    (funcall ',callback proc))))))

;; metals

;;;###autoload
(defun scala-bootstrap:maybe-async-install-coursier (callback)
  (if (executable-find "coursier")
      (funcall callback)
    (let ((output (expand-file-name "coursier" scala-bootstrap:bin-directory)))
      (scala-bootstrap-async-command
       "install-coursier"
       (list "curl" "-vL" "-o"
             (shell-quote-argument output)
             "https://git.io/coursier-cli-linux")
       `(lambda (&rest args)
          (call-process-shell-command
           (format "chmod a+x %s" (shell-quote-argument ,output)))
          (funcall ',callback))))))

(defun scala-bootstrap-parse-metals-version-from-json (json)
  (let* ((tag (gethash "tag_name" json)))
    (string-remove-prefix "v" tag)))

(defun scala-bootstrap-async-metals-latest-version (callback)
  (scala-bootstrap-async-command
   "install-metals"
   (list "curl" "-sL" scala-bootstrap-metals-releases-api)
   `(lambda (proc)
      (let* ((buf (process-buffer proc))
             (version
              (with-current-buffer (prog1 buf
                                     (unless (buffer-live-p buf)
                                       (error "No response buffer")))
                (save-excursion
                  (goto-char (point-min))
                  (let* ((json-object-type 'hash-table)
                         (json-array-type 'list)
                         (json-key-type 'string)
                         (json (ignore-errors (json-read))))
                    (scala-bootstrap-parse-metals-version-from-json json))))))
        (message "The latest version of Metals: %s" version)
        (funcall ',callback
                 (format scala-bootstrap-metals-artifact-template
                         scala-bootstrap:metals-scala-version
                         version))))))

(defun scala-bootstrap-metals-binary ()
  (expand-file-name "metals-emacs" scala-bootstrap:bin-directory))

;;;###autoload
(defun scala-bootstrap:maybe-async-install-metals (callback)
  (if (executable-find "metals-emacs")
      (funcall callback)
    (let ((install-fun
           `(lambda (artifact)
              (let ((callback ',callback)
                    (output (scala-bootstrap-metals-binary)))
                (message "Install %s to %s" artifact output)
                (scala-bootstrap-async-command
                 "install-metals"
                 (list "coursier" "bootstrap"
                       "--java-opt" "-Xss4m"
                       "--java-opt" "-Xms100m"
                       "--java-opt" "-Dmetals.client=emacs"
                       artifact
                       "-r" "bintray:scalacenter/releases"
                       "-r" "sonatype:releases"
                       "-o" output "-f")
                 `(lambda (&rest args) (funcall ',callback)))))))
      (if scala-bootstrap:metals-version
          (funcall install-fun scala-bootstrap:metals-version)
        (scala-bootstrap-async-metals-latest-version install-fun)))))

;;;###autoload
(defun scala-bootstrap:reinstall-metals ()
  "Reinstall Metals."
  (interactive)
  (call-process-shell-command
   (format "rm -f %s" (shell-quote-argument (scala-bootstrap-metals-binary))))
  (scala-bootstrap:maybe-async-install-metals 'ignore))

;; bloop

(defun scala-bootstrap-bloop-binary ()
  (expand-file-name "bloop" scala-bootstrap:bin-directory))

;;;###autoload
(defun scala-bootstrap:maybe-async-install-bloop (callback)
  (if (executable-find "bloop")
      (funcall callback)
    (let ((output scala-bootstrap:bin-directory))
      (message "Install bloop to %s" (scala-bootstrap-bloop-binary))
      (scala-bootstrap-async-command
       "install-bloop"
       (list "coursier" "install" "bloop" "--only-prebuilt=true" "--dir" output)
       `(lambda (&rest args) (funcall ',callback))))))

;;;###autoload
(defun scala-bootstrap:reinstall-bloop ()
  "Reinstall Bloop."
  (interactive)
  (call-process-shell-command
   (format "rm -f %s" (shell-quote-argument (scala-bootstrap-bloop-binary))))
  (scala-bootstrap:maybe-async-install-bloop 'ignore))

;;;###autoload
(defun scala-bootstrap:start-bloop-server ()
  (message "Start bloop server")
  (start-process
   (scala-bootstrap-process-buffer-name "bloop-server")
   "*bloop-server*"
   "bloop" "server"))

;; syntax

;;;###autoload
(defmacro scala-bootstrap:with-metals-installed (&rest body)
  "Ensure that Metals is installed.  It is installed to a
directory specified by `scala-bootstrap:bin-directory', which
defaults to '~/.emacs.d/bin'.

If `scala-bootstrap:metals-version' is non-nill, that version of
Metals will be installed.  Otherwise, the latest version will be
installed.

It also installs Coursier binary in background, which is needed
to install Metals."
  `(let ((buf (current-buffer)) (body ',body))
     (scala-bootstrap-enable-bin-directory)
     (scala-bootstrap:maybe-async-install-coursier
      `(lambda ()
         (let ((buf ,buf) (body ',body))
         (scala-bootstrap:maybe-async-install-metals
          `(lambda ()
             (with-current-buffer ,buf
               ,@body))))))))

;;;###autoload
(defmacro scala-bootstrap:with-bloop-installed (&rest body)
  "Ensure that Bloop is installed.  It is installed to a
directory specified by `scala-bootstrap:bin-directory', which
defaults to '~/.emacs.d/bin'.

If `scala-bootstrap:bloop-version' is non-nill, that version of
Bloop will be installed.  Otherwise, the latest version will be
installed."
  `(let ((buf (current-buffer)) (body ',body))
     (scala-bootstrap-enable-bin-directory)
     (scala-bootstrap:maybe-async-install-coursier
      `(lambda ()
         (let ((buf ,buf) (body ',body))
           (scala-bootstrap:maybe-async-install-bloop
            `(lambda ()
               (with-current-buffer ,buf
                 ,@body))))))))

;;;###autoload
(defmacro scala-bootstrap:with-bloop-server-started (&rest body)
  "Ensure that Bloop server is started.  If there is one
somewhere on your machine, it does nothing.  Otherwise, a server
will be started as a process which appears in `list-processes'
and whose logs appear in '*bloop-server*' buffer.

This macro also ensures that Bloop is installed before starting a
server.
"
  `(scala-bootstrap:with-bloop-installed
    (unless (= 0 (call-process-shell-command "bloop about"))
      (scala-bootstrap:start-bloop-server))
    ,@body))

(provide 'scala-bootstrap)
;;; scala-bootstrap.el ends here
