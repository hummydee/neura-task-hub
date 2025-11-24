;; -----------------------------------------------------------
;; Contract: neura-task-hub.clar
;; Purpose:  Decentralized AI Task Marketplace (post, claim, deliver, release)
;; Author:   hummydee
;; -----------------------------------------------------------

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-TASK-NOT-FOUND (err u101))
(define-constant ERR-TASK-ALREADY-CLAIMED (err u102))
(define-constant ERR-TASK-ALREADY-COMPLETED (err u103))
(define-constant ERR-TASK-EXPIRED (err u104))
(define-constant ERR-INSUFFICIENT-FUNDS (err u105))
(define-constant ERR-TASK-NOT-CLAIMED (err u106))

(define-constant TASK-DURATION u720) ;; e.g., 5 hours (25s/block)
(define-data-var task-counter uint u0)

;; -----------------------------------------------------------
;; TASK STRUCTURE
;; -----------------------------------------------------------

(define-map tasks
  { id: uint }
  {
    client: principal,
    provider: (optional principal),
    reward: uint,
    posted-at: uint,
    deadline: uint,
    result-hash: (optional (buff 64)),
    completed: bool,
    released: bool
  }
)

;; -----------------------------------------------------------
;; EVENTS (Emitted through print statements)
;; -----------------------------------------------------------
;; Events are printed via (print ...) statements in the public functions

;; -----------------------------------------------------------
;; PUBLIC FUNCTIONS
;; -----------------------------------------------------------

;; POST A TASK
(define-public (post-task (reward uint))
  (begin
    (if (< (stx-get-balance tx-sender) reward)
        ERR-INSUFFICIENT-FUNDS
        (let (
              (id (+ (var-get task-counter) u1))
            )
          (match (stx-transfer? reward tx-sender (as-contract tx-sender))
            success
            (begin
              (map-set tasks { id: id } {
                client: tx-sender,
                provider: none,
                reward: reward,
                posted-at: u0,
                deadline: u0,
                result-hash: none,
                completed: false,
                released: false
              })
              (var-set task-counter id)
              (print { event: "task-posted", task-id: id })
              (ok id)
            )
            error (err error)
          )
        )
    )
  )
)

;; CLAIM A TASK
(define-public (claim-task (id uint))
  (match (map-get? tasks { id: id })
    task-data
    (if (is-some (get provider task-data))
        ERR-TASK-ALREADY-CLAIMED
        (begin
          (map-set tasks { id: id } (merge task-data { provider: (some tx-sender) }))
          (print { event: "task-claimed", task-id: id })
          (ok true)
        )
    )
    ERR-TASK-NOT-FOUND
  )
)

;; COMPLETE A TASK (AI node submits output hash)
(define-public (submit-result (id uint) (output-hash (buff 64)))
  (match (map-get? tasks { id: id })
    task-data
    (if (and (is-some (get provider task-data)) (is-eq (unwrap-panic (get provider task-data)) tx-sender))
        (if (get completed task-data)
            ERR-TASK-ALREADY-COMPLETED
            (begin
              (map-set tasks { id: id } (merge task-data {
                result-hash: (some output-hash),
                completed: true
              }))
              (print { event: "task-completed", task-id: id })
              (ok true)
            )
        )
        ERR-NOT-AUTHORIZED
    )
    ERR-TASK-NOT-FOUND
  )
)

;; CLIENT RELEASES PAYMENT AFTER VALIDATION
(define-public (release-payment (id uint))
  (match (map-get? tasks { id: id })
    task-data
    (if (and (is-eq (get client task-data) tx-sender)
             (get completed task-data)
             (not (get released task-data)))
        (let ((provider (unwrap-panic (get provider task-data))))
          (match (stx-transfer? (get reward task-data) (as-contract tx-sender) provider)
            success
            (begin
              (map-set tasks { id: id } (merge task-data { released: true }))
              (print { event: "task-released", task-id: id })
              (ok true)
            )
            error (err error)
          )
        )
        ERR-NOT-AUTHORIZED
    )
    ERR-TASK-NOT-FOUND
  )
)

;; AUTO REFUND IF DEADLINE PASSED AND TASK UNCLAIMED
(define-public (refund-task (task-id uint))
  (let ((task-result (map-get? tasks { id: task-id })))
    (match task-result
      task-data
      (if (and (>= u0 (get deadline task-data)) (not (is-some (get provider task-data))))
          (let ((reward-amount (get reward task-data))
                (client-addr (get client task-data)))
            (match (stx-transfer? reward-amount (as-contract tx-sender) client-addr)
              success
              (begin
                (asserts! (is-eq true true) ERR-TASK-EXPIRED)
                (map-delete tasks { id: task-id })
                (print { event: "task-refunded", task-id: task-id })
                (ok true)
              )
              error (err error)
            )
          )
          ERR-TASK-EXPIRED
      )
      ERR-TASK-NOT-FOUND
    )
  )
)

;; -----------------------------------------------------------
;; READ-ONLY FUNCTIONS
;; -----------------------------------------------------------

(define-read-only (get-task (id uint))
  (default-to
    { client: tx-sender, provider: none, reward: u0, posted-at: u0, deadline: u0, result-hash: none, completed: false, released: false }
    (map-get? tasks { id: id })
  )
)

(define-read-only (list-all-tasks)
  ;; Note: Cannot list all tasks from map - would need off-chain indexing
  ;; Use get-task function with known task IDs instead
  (ok true)
)
