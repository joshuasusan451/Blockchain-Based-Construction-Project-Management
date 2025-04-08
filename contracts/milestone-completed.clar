;; Milestone Completion Contract
;; This contract records progress and triggers payments

(define-data-var admin principal tx-sender)

;; Data structure for project information
(define-map projects
  { project-id: (string-ascii 20) }
  {
    name: (string-ascii 100),
    contractor-id: (string-ascii 20),
    total-milestones: uint,
    completed-milestones: uint,
    total-budget: uint,
    paid-amount: uint,
    start-date: uint,
    end-date: uint,
    is-completed: bool
  }
)

;; Data structure for milestone information
(define-map milestones
  { project-id: (string-ascii 20), milestone-id: uint }
  {
    description: (string-ascii 200),
    amount: uint,
    deadline: uint,
    is-completed: bool,
    completion-date: uint,
    is-paid: bool
  }
)

;; Public function to register a new project (only admin)
(define-public (register-project
    (project-id (string-ascii 20))
    (name (string-ascii 100))
    (contractor-id (string-ascii 20))
    (total-milestones uint)
    (total-budget uint)
    (start-date uint)
    (end-date uint))
  (begin
    (asserts! (is-admin tx-sender) (err u1))
    (asserts! (is-none (map-get? projects { project-id: project-id })) (err u2))
    (ok (map-set projects
      { project-id: project-id }
      {
        name: name,
        contractor-id: contractor-id,
        total-milestones: total-milestones,
        completed-milestones: u0,
        total-budget: total-budget,
        paid-amount: u0,
        start-date: start-date,
        end-date: end-date,
        is-completed: false
      }
    ))
  )
)

;; Public function to add a milestone to a project (only admin)
(define-public (add-milestone
    (project-id (string-ascii 20))
    (milestone-id uint)
    (description (string-ascii 200))
    (amount uint)
    (deadline uint))
  (begin
    (asserts! (is-admin tx-sender) (err u1))
    (asserts! (is-some (map-get? projects { project-id: project-id })) (err u3))
    (asserts! (is-none (map-get? milestones { project-id: project-id, milestone-id: milestone-id })) (err u2))
    (ok (map-set milestones
      { project-id: project-id, milestone-id: milestone-id }
      {
        description: description,
        amount: amount,
        deadline: deadline,
        is-completed: false,
        completion-date: u0,
        is-paid: false
      }
    ))
  )
)

;; Public function to mark a milestone as completed (only admin)
(define-public (complete-milestone (project-id (string-ascii 20)) (milestone-id uint))
  (begin
    (asserts! (is-admin tx-sender) (err u1))
    (asserts! (is-some (map-get? projects { project-id: project-id })) (err u3))
    (asserts! (is-some (map-get? milestones { project-id: project-id, milestone-id: milestone-id })) (err u3))

    ;; Update milestone as completed
    (map-set milestones
      { project-id: project-id, milestone-id: milestone-id }
      (merge (unwrap-panic (map-get? milestones { project-id: project-id, milestone-id: milestone-id }))
        {
          is-completed: true,
          completion-date: block-height
        }
      )
    )

    ;; Update project completed milestones count
    (let ((project (unwrap-panic (map-get? projects { project-id: project-id }))))
      (map-set projects
        { project-id: project-id }
        (merge project
          {
            completed-milestones: (+ (get completed-milestones project) u1)
          }
        )
      )
    )

    (ok true)
  )
)

;; Public function to mark a milestone as paid (only admin)
(define-public (pay-milestone (project-id (string-ascii 20)) (milestone-id uint))
  (begin
    (asserts! (is-admin tx-sender) (err u1))
    (asserts! (is-some (map-get? projects { project-id: project-id })) (err u3))
    (asserts! (is-some (map-get? milestones { project-id: project-id, milestone-id: milestone-id })) (err u3))

    (let (
      (milestone (unwrap-panic (map-get? milestones { project-id: project-id, milestone-id: milestone-id })))
      (project (unwrap-panic (map-get? projects { project-id: project-id })))
    )
      ;; Check if milestone is completed but not paid
      (asserts! (get is-completed milestone) (err u4))
      (asserts! (not (get is-paid milestone)) (err u5))

      ;; Update milestone as paid
      (map-set milestones
        { project-id: project-id, milestone-id: milestone-id }
        (merge milestone { is-paid: true })
      )

      ;; Update project paid amount
      (map-set projects
        { project-id: project-id }
        (merge project
          {
            paid-amount: (+ (get paid-amount project) (get amount milestone))
          }
        )
      )

      (ok true)
    )
  )
)

;; Public function to mark a project as completed (only admin)
(define-public (complete-project (project-id (string-ascii 20)))
  (begin
    (asserts! (is-admin tx-sender) (err u1))
    (asserts! (is-some (map-get? projects { project-id: project-id })) (err u3))

    (let ((project (unwrap-panic (map-get? projects { project-id: project-id }))))
      ;; Check if all milestones are completed
      (asserts! (is-eq (get completed-milestones project) (get total-milestones project)) (err u6))

      ;; Update project as completed
      (ok (map-set projects
        { project-id: project-id }
        (merge project { is-completed: true })
      ))
    )
  )
)

;; Public function to get project details
(define-read-only (get-project-details (project-id (string-ascii 20)))
  (map-get? projects { project-id: project-id })
)

;; Public function to get milestone details
(define-read-only (get-milestone-details (project-id (string-ascii 20)) (milestone-id uint))
  (map-get? milestones { project-id: project-id, milestone-id: milestone-id })
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
