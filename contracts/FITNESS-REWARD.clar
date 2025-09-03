;; Fitness Rewards - Earn tokens for workouts/steps
;; Version: 1.0.0

;; -----------------------
;; Constants & Globals
;; -----------------------
(define-data-var owner (optional principal) none) ;; set once via init-owner()
(define-fungible-token FIT)
(define-data-var total-supply uint u0)

;; Map of verifiers: key { who: principal } -> { active: bool, added-by: principal }
(define-map verifiers
  { who: principal }
  { active: bool, added-by: principal }
)

;; -----------------------
;; Error codes
;; -----------------------
(define-constant ERR-UNAUTHORIZED u100)
(define-constant ERR-ALREADY_INIT u101)
(define-constant ERR-NOT-VERIFIER u102)
(define-constant ERR-ZERO-AMOUNT u103)
(define-constant ERR-TRANSFER-FAIL u104)
(define-constant ERR-NOT-FOUND u105)
 (define-constant ERR-ALREADY-VERIFIER u106)

;; -----------------------
;; Initialization
;; -----------------------
;; Call once after deploy to claim the owner role (tx-sender becomes owner).
(define-public (init-owner)
  (begin
    (asserts! (is-none (var-get owner)) (err ERR-ALREADY_INIT))
    (var-set owner (some tx-sender))
    (ok tx-sender)
  )
)

;; -----------------------
;; Owner-only helpers
;; -----------------------
(define-read-only (get-owner)
  (ok (var-get owner))
)

(define-private (only-owner)
  (begin
    (let ((maybe-o (var-get owner)))
      (asserts! (is-some maybe-o) (err ERR-UNAUTHORIZED))
      (asserts! (is-eq (unwrap-panic maybe-o) tx-sender) (err ERR-UNAUTHORIZED))
      (ok true)
    )
  )
)

;; -----------------------
;; Verifier management
;; -----------------------
(define-public (add-verifier (who principal))
  (begin
    (try! (only-owner))
    (match (map-get? verifiers { who: who })
      entry (err ERR-ALREADY-VERIFIER)
      (begin
  (map-set verifiers { who: who } { active: true, added-by: tx-sender })
  (ok who)
      )
    )
  )
)

(define-public (remove-verifier (who principal))
  (begin
    (try! (only-owner))
    (match (map-get? verifiers { who: who })
      entry
        (begin
          (asserts! (map-delete verifiers { who: who }) (err ERR-NOT-FOUND))
          (ok who)
        )
      (err ERR-NOT-FOUND)
    )
  )
)

(define-read-only (is-verifier (who principal))
  (match (map-get? verifiers { who: who })
    entry (ok (get active entry))
    (ok false)
  )
)

;; -----------------------
;; Rewarding (Minting)
;; -----------------------
;; Only active verifiers may call reward to mint FIT to a recipient.
(define-public (reward (to principal) (amount uint))
  (begin
    (asserts! (> amount u0) (err ERR-ZERO-AMOUNT))
    ;; check verifier active
    (let ((isv (match (map-get? verifiers { who: tx-sender })
                  entry (get active entry)
                  false)))
      (asserts! isv (err ERR-NOT-VERIFIER))
      ;; mint
      (asserts! (is-ok (ft-mint? FIT amount to)) (err ERR-TRANSFER-FAIL))
      (var-set total-supply (+ (var-get total-supply) amount))
      (ok amount)
    )
  )
)

;; -----------------------
;; SIP-010 interface & helpers
;; -----------------------
(define-read-only (get-name) (ok "Fitness Token"))
(define-read-only (get-symbol) (ok "FIT"))
(define-read-only (get-decimals) (ok u6))
(define-read-only (get-total-supply) (ok (var-get total-supply)))
(define-read-only (get-balance (who principal))
  (ok (ft-get-balance FIT who))
)

;; transfer wrapper: requires tx-sender == sender
(define-public (transfer (amount uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq sender tx-sender) (err ERR-UNAUTHORIZED))
  (try! (ft-transfer? FIT amount sender recipient))
  (ok true)
  )
)

;; transfer-memo wrapper (simple pass-through)
(define-public (transfer-memo (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq sender tx-sender) (err ERR-UNAUTHORIZED))
  (try! (ft-transfer? FIT amount sender recipient))
  (ok true)
  )
)

;; -----------------------
;; Admin read-only helpers for convenience
;; -----------------------
(define-read-only (list-verifier (who principal))
  (map-get? verifiers { who: who })
)
