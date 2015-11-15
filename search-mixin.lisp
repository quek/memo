(in-package  :letter)

(named-readtables:in-readtable info.read-eval-print.double-quote:|#"|)

(defclass search-mixin ()
  ())

(defgeneric search-fields (self))
(defgeneric search-index (self))

(defmethod search-fields (self)
  nil)

(defmethod search-index (self)
  (flet ((str ()
           (with-output-to-string (out)
             (loop for i in (search-fields self)
                   do (awhen (cond ((symbolp i)
                                    (slot-value self i))
                                   ((functionp i)
                                    (funcall i self)))
                        (princ it out)
                        (write-char #\space out)))))
         (add (word)
           (zinc (search-key word) self)))
    (search-remove self)
    (let ((words (search-tokenize (str))))
      (loop for s in words
            do (add s))
      (hset *word-hash-key* self (remove-duplicates words :test #'equal)))))

(defmethod search-remove (self)
  (loop for word in (hget *word-hash-key* self)
        do (zrem (search-key word) self)))

(defun search-tokenize (string)
  (flet ((normalize (s)
           (reduce (lambda (s f) (funcall f s))
                   (list #'string-downcase
                         (lambda (s)
                           (ppcre:regex-replace-all "[。、,.\\s]" s "")))
                   :initial-value s)))
    (loop with str = (normalize string)
          for i from 0 below (1- (length str))
          for s = (subseq str i (+ i 2))
          collect s)))

(defun search-search (string &key (with-scores nil))
  (let ((words (search-tokenize string))
        (dest #"""tmp #,string"""))
    (when words
      (unwind-protect
           (progn
             (zinterstore dest (mapcar #'search-key words))
             (zrang dest 0 nil :from-end t :with-scores with-scores))
        (del dest)))))

#+nil
(prong
 (mapc #'search-index (zrang *titles* 0 nil))
 (mapc #'del (keys "^s ")))

