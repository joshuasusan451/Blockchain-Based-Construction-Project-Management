;; Material Verification Contract
;; This contract tracks quality and origin of building supplies

(define-data-var admin principal tx-sender)

;; Data structure for material information
(define-map materials
  { material-id: (string-ascii 20) }
  {
    name: (string-ascii 100),
    supplier: (string-ascii 100),
    origin: (string-ascii 50),
    quality-grade: (string-ascii 10),
    verification-date: uint,
    is-verified: bool
  }
)

;; Data structure for material batches
(define-map material-batches
  { batch-id: (string-ascii 20) }
  {
    material-id: (string-ascii 20),
    quantity: uint,
    production-date: uint,
    expiration-date: uint,
    is-used: bool
  }
)

;; Public function to register a new material (only admin)
(define-public (register-material
    (material-id (string-ascii 20))
    (name (string-ascii 100))
    (supplier (string-ascii 100))
    (origin (string-ascii 50))
    (quality-grade (string-ascii 10)))
  (begin
    (asserts! (is-admin tx-sender) (err u1))
    (asserts! (is-none (map-get? materials { material-id: material-id })) (err u2))
    (ok (map-set materials
      { material-id: material-id }
      {
        name: name,
        supplier: supplier,
        origin: origin,
        quality-grade: quality-grade,
        verification-date: u0,
        is-verified: false
      }
    ))
  )
)

;; Public function to verify a material (only admin)
(define-public (verify-material (material-id (string-ascii 20)))
  (begin
    (asserts! (is-admin tx-sender) (err u1))
    (asserts! (is-some (map-get? materials { material-id: material-id })) (err u3))
    (ok (map-set materials
      { material-id: material-id }
      (merge (unwrap-panic (map-get? materials { material-id: material-id }))
        {
          verification-date: block-height,
          is-verified: true
        }
      )
    ))
  )
)

;; Public function to register a material batch
(define-public (register-batch
    (batch-id (string-ascii 20))
    (material-id (string-ascii 20))
    (quantity uint)
    (production-date uint)
    (expiration-date uint))
  (begin
    (asserts! (is-admin tx-sender) (err u1))
    (asserts! (is-some (map-get? materials { material-id: material-id })) (err u3))
    (asserts! (is-none (map-get? material-batches { batch-id: batch-id })) (err u2))
    (ok (map-set material-batches
      { batch-id: batch-id }
      {
        material-id: material-id,
        quantity: quantity,
        production-date: production-date,
        expiration-date: expiration-date,
        is-used: false
      }
    ))
  )
)

;; Public function to mark a batch as used
(define-public (use-batch (batch-id (string-ascii 20)))
  (begin
    (asserts! (is-admin tx-sender) (err u1))
    (asserts! (is-some (map-get? material-batches { batch-id: batch-id })) (err u3))
    (ok (map-set material-batches
      { batch-id: batch-id }
      (merge (unwrap-panic (map-get? material-batches { batch-id: batch-id }))
        { is-used: true }
      )
    ))
  )
)

;; Public function to check if a material is verified
(define-read-only (is-material-verified (material-id (string-ascii 20)))
  (match (map-get? materials { material-id: material-id })
    material (ok (get is-verified material))
    (err u3)
  )
)

;; Public function to get material details
(define-read-only (get-material-details (material-id (string-ascii 20)))
  (map-get? materials { material-id: material-id })
)

;; Public function to get batch details
(define-read-only (get-batch-details (batch-id (string-ascii 20)))
  (map-get? material-batches { batch-id: batch-id })
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
