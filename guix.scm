;; SPDX-License-Identifier: MPL-2.0
;; Guix development environment template.
;; Usage: guix shell -D -f guix.scm

(use-modules (guix packages)
             (guix build-system gnu)
             (guix licenses)
             (gnu packages base)
             (gnu packages bash))

(package
  (name "marid")
  (version "0.1.0")
  (source #f)
  (build-system gnu-build-system)
  (inputs (list coreutils bash))
  (synopsis "marid")
  (description "marid — part of the hyperpolymath ecosystem.")
  (home-page "https://github.com/hyperpolymath/marid")
  (license (@ (guix licenses) mpl2.0)))
