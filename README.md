scala-bootstrap.el
==================

A bootstrapping installer for Scala tools.

Synopsis
--------

This package provides an installer of Scala tools, which is convenient
if you are using [lsp-mode][].

```elisp
(require 'scala-bootstrap)
(require 'lsp-mode)

(add-hook 'scala-mode-hook
          '(lambda ()
             (scala-bootstrap:with-metals-installed
              (scala-bootstrap:with-bloop-server-started
               (lsp)))))
```

Macros
------

### `scala-bootstrap:with-metals-installed` (`&rest body`)

Ensures that [Metals][] is installed.  It is installed to a directory
specified by `scala-bootstrap:bin-directory`, which defaults to
`~/.emacs.d/bin`.

If `scala-bootstrap:metals-version` is non-nill, that version of
[Metals][] will be installed.  Otherwise, the latest version will be
installed.

It also installs [Coursier][] binary in background, which is needed to
install [Metals][].

### `scala-bootstrap:with-bloop-installed` (`&rest body`)

Ensures that [Bloop][] is installed.  It is installed to a directory
specified by `scala-bootstrap:bin-directory`, which defaults to
`~/.emacs.d/bin`.

If `scala-bootstrap:bloop-version` is non-nill, that version of
[Bloop][] will be installed.  Otherwise, the latest version will be
installed.

### `scala-bootstrap:with-bloop-server-started` (`&rest body`)

Ensures that [Bloop][] server is started.  If there is one somewhere
on your machine, it does nothing.  Otherwise, a server will be started
as a process which appears in `M-x list-processes` and whose logs
appear in `*bloop-server*` buffer.

This macro also ensures that [Bloop][] is installed before starting a
server.

Funcitions
----------

### `scala-bootstrap:reinstall-metals` ()

Reinstalls [Metals][].

### `scala-bootstrap:reinstall-bloop` ()

Reinstalls [Bloop][].

Variables
---------

### `scala-bootstrap:bin-directory`

Directory to place installed tools.

### `scala-bootstrap:metals-scala-version`

Scala version of [Metals][].

### `scala-bootstrap:metals-version`

[Metals][] version to install.

### `scala-bootstrap:bloop-version`

[Bloop][] version to install.

[Metals]: https://scalameta.org/metals/
[Bloop]: https://scalacenter.github.io/bloop/
[Coursier]: https://get-coursier.io/
[lsp-mode]: https://github.com/emacs-lsp/lsp-mode
