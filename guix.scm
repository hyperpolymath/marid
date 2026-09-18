;; SPDX-License-Identifier: MPL-2.0
;; Guix development environment template.
;; Usage: guix shell -D -f guix.scm

(use-modules (guix packages)
             (guix build-system gnu)
             (guix licenses)
             (gnu packages base)
             (gnu packages bash))

(package
  (name "rsr-template-repo")
  (version "0.1.0")
  (source #f)
  (build-system gnu-build-system)
  (inputs (list coreutils bash))
  (synopsis "rsr-template-repo")
  (description "rsr-template-repo — part of the hyperpolymath ecosystem.")
  (home-page "https://github.com/hyperpolymath/rsr-template-repo")
  (license (@ (guix licenses) mpl2.0)))
