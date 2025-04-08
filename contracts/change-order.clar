;; Change Order Contract
;; This contract manages modifications to original project scope

(define-data-var admin principal tx-sender)

;; Change order status enum: 0=Pending, 1=Approved, 2=Rejected
(define-constant STATUS-PENDING u0)
(define-constant STATUS-APPROVED u1)
(define-constant STATUS-REJECTED u2)

;; Data structure for change order information
(define-map change-orders
  { project-id: (string-ascii 20), change-order-id: uint }
  {
    description: (string-ascii 200),
    cost-impact: int,
    time-impact: int,
    requester: principal,
    request-date: uint,
    status: uint,
    review-date: uint,
    reviewer: (optional principal)
  }
)

;; Data structure to track change order count per project
(define-map project-change-order-count
  { project-id: (string-ascii 20) }
  { count: uint }
)

;; Public function to request a change order
(define-public (request-change-order
    (project-id (string-ascii 20))
    (description (string-ascii 200))
    (cost-impact int)
    (time-impact int))
  (let (
    (change-order-id (get-next-change-order-id project-id))
  )
    (ok (map-set change-orders
      { project-id: project-id, change-order-id: change-order-id }
      {
        description: description,
        cost-impact: cost-impact,
        time-impact: time-impact,
        requester: tx-sender,
        request-date: block-height,
        status: STATUS-PENDING,
        review-date: u0,
        reviewer: none
      }
    ))
  )
)

;; Public function to approve a change order (only admin)
(define-public (approve-change-order (project-id (string-ascii 20)) (change-order-id uint))
  (begin
    (asserts! (is-admin tx-sender) (err u1))
    (asserts! (is-some (map-get? change-orders { project-id: project-id, change-order-id: change-order-id })) (err u3))

    (let ((change-order (unwrap-panic (map-get? change-orders { project-id: project-id, change-order-id: change-order-id }))))
      ;; Check if change order is pending
      (asserts! (is-eq (get status change-order) STATUS-PENDING) (err u4))

      ;; Update change order as approved
      (ok (map-set change-orders
        { project-id: project-id, change-order-id: change-order-id }
        (merge change-order
          {
            status: STATUS-APPROVED,
            review-date: block-height,
            reviewer: (some tx-sender)
          }
        )
      ))
    )
  )
)

;; Public function to reject a change order (only admin)
(define-public (reject-change-order (project-id (string-ascii 20)) (change-order-id uint))
  (begin
    (asserts! (is-admin tx-sender) (err u1))
    (asserts! (is-some (map-get? change-orders { project-id: project-id, change-order-id: change-order-id })) (err u3))

    (let ((change-order (unwrap-panic (map-get? change-orders { project-id: project-id, change-order-id: change-order-id }))))
      ;; Check if change order is pending
      (asserts! (is-eq (get status change-order) STATUS-PENDING) (err u4))

      ;; Update change order as rejected
      (ok (map-set change-orders
        { project-id: project-id, change-order-id: change-order-id }
        (merge change-order
          {
            status: STATUS-REJECTED,
            review-date: block-height,
            reviewer: (some tx-sender)
          }
        )
      ))
    )
  )
)

;; Private function to get the next change order ID for a project
(define-private (get-next-change-order-id (project-id (string-ascii 20)))
  (let ((current-count (default-to { count: u0 } (map-get? project-change-order-count { project-id: project-id }))))
    (begin
      (map-set project-change-order-count
        { project-id: project-id }
        { count: (+ (get count current-count) u1) }
      )
      (+ (get count current-count) u1)
    )
  )
)

;; Public function to get change order details
(define-read-only (get-change-order-details (project-id (string-ascii 20)) (change-order-id uint))
  (map-get? change-orders { project-id: project-id, change-order-id: change-order-id })
)

;; Public function to get change order count for a project
(define-read-only (get-change-order-count (project-id (string-ascii 20)))
  (default-to { count: u0 } (map-get? project-change-order-count { project-id: project-id }))
)

;; Public function to get change order status
(define-read-only (get-change-order-status (project-id (string-ascii 20)) (change-order-id uint))
  (match (map-get? change-orders { project-id: project-id, change-order-id: change-order-id })
    change-order (ok (get status change-order))
    (err u3)
  )
)

;; Private function to check if caller is admin
(define-private (is-admin (caller principal))
  (is-eq caller (var-get admin))
)

;; Public function to transfer admin rights (only current admin)
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin tx-sender) (err u1))
    (ok (var-set admin new-admin))
  )
)
