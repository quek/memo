(asdf:defsystem :letter
  :version "0.0.1"
  :serial t
  :components ((:file "packages")
               (:file "config")
               (:file "util")
               (:file "condition")
               (:file "key")
               (:file "model")
               (:file "letter")
               (:file "css")
               (:file "public"))
  :depends-on (:info.read-eval-print.series-ext
               :info.read-eval-print.double-quote
               :info.read-eval-print.lambda
               :3bmd
               :3bmd-ext-code-blocks
               :anaphora
               :parenscript
               :oauth2
               :diff
               :cl-ppcre
               :hu.dwim.defclass-star
               :unpyo
               :lepis))