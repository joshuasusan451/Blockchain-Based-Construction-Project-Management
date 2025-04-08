;; Contractor Verification Contract
;; This contract validates qualified construction companies

(define-data-var admin principal tx-sender)

;; Data structure for contractor information
(define-map contractors
  { contractor-id: (string-ascii 20) }
  {
    name: (string-ascii 100),
    license-number: (string-ascii 50),
    is-verified: bool,
    verification-date: uint,
    rating: uint
  }
)

;; Public function to register a new contractor (only admin)
(define-public (register-contractor (contractor-id (string-ascii 20)) (name (string-ascii 100)) (license-number (string-ascii 50)))
  (begin
    (asserts! (is-admin tx-sender) (err u1))
    (asserts! (is-none (map-get? contractors { contractor-id: contractor-id })) (err u2))
    (ok (map-set contractors
      { contractor-id: contractor-id }
      {
        name: name,
        license-number: license-number,
        is-verified: false,
        verification-date: u0,
        rating: u0
      }
    ))
  )
)

;; Public function to verify a contractor (only admin)
(define-public (verify-contractor (contractor-id (string-ascii 20)) (rating uint))
  (begin
    (asserts! (is-admin tx-sender) (err u1))
    (asserts! (is-some (map-get? contractors { contractor-id: contractor-id })) (err u3))
    (asserts! (<= rating u5) (err u4))
    (ok (map-set contractors
      { contractor-id: contractor-id }
      (merge (unwrap-panic (map-get? contractors { contractor-id: contractor-id }))
        {
          is-verified: true,
          verification-date: block-height,
          rating: rating
        }
      )
    ))
  )
)

;; Public function to check if a contractor is verified
(define-read-only (is-contractor-verified (contractor-id (string-ascii 20)))
  (match (map-get? contractors { contractor-id: contractor-id })
    contractor (ok (get is-verified contractor))
    (err u3)
  )
)

;; Public function to get contractor details
(define-read-only (get-contractor-details (contractor-id (string-ascii 20)))
  (map-get? contractors { contractor-id: contractor-id })
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
