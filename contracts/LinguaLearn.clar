;; LinguaLearn - Language learning progress tracking and fluency rewards platform
(define-data-var language-instructor principal tx-sender)
(define-data-var total-proficiency-points uint u0)
(define-data-var fluency-bonus-rate uint u30) ;; bonus points per proficiency level
(define-data-var last-fluency-assessment uint u0)

(define-map learner-proficiency principal uint)
(define-map target-languages principal (string-utf8 64))
(define-map supported-languages (string-utf8 64) bool)

;; Error codes
(define-constant err-unauthorized-instructor (err u1800))
(define-constant err-instructor-already-assigned (err u1801))
(define-constant err-invalid-proficiency-points (err u1802))
(define-constant err-no-fluency-bonuses (err u1803))
(define-constant err-no-proficiency-progress (err u1804))
(define-constant err-invalid-language (err u1805))
(define-constant err-language-not-supported (err u1806))

;; Verify instructor authorization
(define-private (is-language-instructor (caller principal))
  (begin
    (asserts! (is-eq caller (var-get language-instructor)) err-unauthorized-instructor)
    (ok true)))

;; Initialize language learning platform
(define-public (establish-language-platform (instructor principal))
  (begin
    (asserts! (is-none (map-get? learner-proficiency instructor)) err-instructor-already-assigned)
    (var-set language-instructor instructor)
    (ok "LinguaLearn language learning platform established")))

;; Add supported language for learning
(define-public (add-supported-language (language (string-utf8 64)))
  (begin
    (try! (is-language-instructor tx-sender))
    (asserts! (> (len language) u0) err-invalid-language)
    (map-set supported-languages language true)
    (ok "Language added to supported learning options")))

;; Record language learning progress
(define-public (record-learning-progress (proficiency-points uint) (target-language (string-utf8 64)))
  (begin
    (asserts! (> proficiency-points u0) err-invalid-proficiency-points)
    (asserts! (default-to false (map-get? supported-languages target-language)) err-language-not-supported)
    
    (let ((current-proficiency (default-to u0 (map-get? learner-proficiency tx-sender))))
      (map-set learner-proficiency tx-sender (+ current-proficiency proficiency-points))
      (map-set target-languages tx-sender target-language)
      (var-set total-proficiency-points (+ (var-get total-proficiency-points) proficiency-points))
      (ok (+ current-proficiency proficiency-points)))))

;; Process fluency achievement bonuses
(define-public (process-fluency-bonuses)
  (begin
    (try! (is-language-instructor tx-sender))
    (let ((current-assessment (+ (var-get last-fluency-assessment) u1))
          (total-points (var-get total-proficiency-points)))
      (asserts! (> total-points (var-get last-fluency-assessment)) err-no-fluency-bonuses)
      
      (let ((fluency-bonus-pool (* (var-get fluency-bonus-rate) total-points)))
        (var-set last-fluency-assessment current-assessment)
        (ok fluency-bonus-pool)))))

;; Complete language certification and claim rewards
(define-public (complete-language-certification)
  (begin
    (let ((learner-points (default-to u0 (map-get? learner-proficiency tx-sender))))
      (asserts! (> learner-points u0) err-no-proficiency-progress)
      
      (let ((total-points (var-get total-proficiency-points))
            (base-fluency-rewards (* (var-get fluency-bonus-rate) learner-points))
            (proficiency-ratio (/ (* learner-points u100000) total-points)))
        
        (let ((final-fluency-rewards (/ (* proficiency-ratio base-fluency-rewards) u100000)))
          (map-delete learner-proficiency tx-sender)
          (map-delete target-languages tx-sender)
          (var-set total-proficiency-points (- (var-get total-proficiency-points) learner-points))
          (ok (+ learner-points final-fluency-rewards)))))))

;; Read-only functions
(define-read-only (get-learner-proficiency (learner principal))
  (default-to u0 (map-get? learner-proficiency learner)))

(define-read-only (get-target-language (learner principal))
  (map-get? target-languages learner))

(define-read-only (get-total-proficiency-points)
  (var-get total-proficiency-points))

(define-read-only (is-language-supported (language (string-utf8 64)))
  (default-to false (map-get? supported-languages language)))