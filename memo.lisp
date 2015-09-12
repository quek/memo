(in-package :memo)

(named-readtables:in-readtable info.read-eval-print.double-quote:|#"|)

(defvar *users* '*users*)

(defun doc-key (title)
  (format nil "doc ~a" title))

;; テンプレート
(defmacro with-defalut-template ((&key (title "memo")) &body contents)
  `(html
     (:!doctype :html t)
     (:html
       :lang "ja"
       (:head (:meta :charset "UTF-8")
         (:title ,title)
         (:script :src "https://code.jquery.com/jquery-2.1.4.min.js")
         (:link :rel "stylesheet" :href "//cdn.jsdelivr.net/editor/0.1.0/editor.css")
         (:script :src "//cdn.jsdelivr.net/editor/0.1.0/editor.js")
         (:script :src "//cdn.jsdelivr.net/editor/0.1.0/marked.js")
         (:link :href "/main.css" :rel "stylesheet" :type "text/css"))
       (:body
           (:div (:a :href "/" "トップ"))
         ,@contents))))

(defaction /main.css ()
  (setf (content-type) "text/css")
  (write-string colorize:*coloring-css* *html-output*)
  (write-string
   (cl-css:css
     `((body :color \#333)
       (".CodeMirror" :height 400px)))
   *html-output*))

(defun markdown-editor (doc)
  (html
    (:textarea :name "doc" doc)
    (:script (ps:ps ($ (lambda ()
                         (ps:let ((editor (ps:new (*editor))))
                           (ps:chain editor (render)))))))))

;; トップページ
(defaction /root (:path "/")
  (with-defalut-template ()
    (:h1 "メモ")
    (:p (:a :href "/new" "新しく作る"))
    (:ul (iterate ((title (scan (zrang "titles" 0 nil :from-end t))))
           (html (:li (:a :href #"""/show/#,title""" title)))))))

(defaction /login ()
  (with-defalut-template ()
    (:a :href #"""https://accounts.google.com/o/oauth2/auth?response_type=code&client_id=#,*oauth-client-id*,&redirect_uri=http://localhost:1959/oauth2callback&scope=https://www.googleapis.com/auth/userinfo.email"""
      "Google アカウントでログイン")))

(defaction /oauth2callback ()
  (let ((token (oauth2:request-token
                "https://www.googleapis.com/oauth2/v3/token"
                @code
                :method :post
                :redirect-uri "http://localhost:1959/oauth2callback"
                :other `(("client_id" . ,*oauth-client-id*)
                         ("client_secret" . ,*oauth-client-secret*)))))
    (with-input-from-string
        (stream
         (map 'string 'code-char
           (oauth2:request-resource "https://www.googleapis.com/oauth2/v2/userinfo"
                                    token)))
      (let* ((userinfo (json:decode-json stream))
             (email (cdr (assoc :email userinfo))))
        (hset *users* email userinfo)
        (with-defalut-template ()
          (html (:pre (hget *users* email))))))))


(defaction /edit/@title ()
  (let ((doc (@ (doc-key @title))))
    (with-defalut-template (:title @title)
      (:h1 @title)
      (:form :action #"""/save/#,@title""" :method "post"
        (:p (:input :type "submit" :value "save"))
        (:p (markdown-editor doc))))))

(defaction /new ()
  (with-defalut-template (:title "新しく作る")
    (:form :action #"""/create""" :method "post"
      (:p (:input :type "submit" :value "save"))
      (:p (:input :type "text" :name "title"))
      (:p (:textarea.edit :name "doc" "")))))

(macrolet ((body ()
             `(unpyo::with-@param
                (! (doc-key @title) @doc)
                (zadd "titles" (get-universal-time) @title)
                (redirect (format nil "/show/~a" @title)))))
  (defaction /create (:method :post)
    (body))
  (defaction /save/@title (:method :post)
    (body)))

(defun print-markdown (doc)
  (let ((3bmd-code-blocks:*code-blocks* t)
        (3bmd-code-blocks:*code-blocks-default-colorize* :common-lisp))
    (3bmd:parse-string-and-print-to-stream doc *html-output*)))

(defaction /show/@title ()
  (let ((doc (@ (doc-key @title))))
    (with-defalut-template (:title @title)
      (:h1 @title)
      (print-markdown doc)
      (:p (:a :href #"""/edit/#,@title""" "編集"))
      (:p (:a :href #"""/delete/#,@title""" "削除")))))

(defaction /delete/@title ()
  (del (doc-key @title))
  (zrem "titles" @title)
  (redirect "/"))

(defvar *server*)

(defclass memo-app (application)
  ())

(defmethod call :around ((app memo-app))
  (with-db ((merge-pathnames "lepis/" *default-directory*))
    (call-next-method)))

(defparameter *oauth-secret-file* (merge-pathnames "google-oauth.lisp" *default-directory*))
(defvar *oauth-client-id* nil)
(defvar *oauth-client-secret* nil)
(defun load-google-oauth ()
  (with-open-file (in *oauth-secret-file*)
    (let ((x (read in)))
      (setf *oauth-client-id* (getf x :client-id)
            *oauth-client-secret* (getf x :client-secret)))))

;; start
(defun start (&key (port *http-port*))
  (format t "http://localhost:~d~%" port)
  (load-google-oauth)
  (unless *db*
    (setf *db* (open-db (merge-pathnames "lepis/" *default-directory*))))
  ;; html
  (setf info.read-eval-print.html:*html-pprint* nil)
  ;; Unpyo
  (setf *invoke-debugger-p* nil)
  (setq *server* (make-server :app (make-instance 'memo-app) :port port))
  (run *server*))

;; stop
(defun stop ()
  (unpyo:stop *server*)
  (when *db*
    (close-db *db*)
    (setf *db* nil)))
