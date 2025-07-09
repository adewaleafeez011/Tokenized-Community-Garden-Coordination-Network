;; Educational Workshop Contract
;; Organizes gardening skill development sessions

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_WORKSHOP_NOT_FOUND (err u401))
(define-constant ERR_WORKSHOP_FULL (err u402))
(define-constant ERR_ALREADY_REGISTERED (err u403))
(define-constant ERR_INVALID_WORKSHOP_DATA (err u405))

;; Data Variables
(define-data-var next-workshop-id uint u1)
(define-data-var total-workshops uint u0)

;; Data Maps
(define-map workshops
  { workshop-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 300),
    instructor: principal,
    category: (string-ascii 50),
    skill-focus: (string-ascii 50),
    scheduled-date: uint,
    duration: uint,
    max-participants: uint,
    current-participants: uint,
    location: (string-ascii 100),
    status: (string-ascii 20),
    created-at: uint
  }
)

(define-map workshop-registrations
  { workshop-id: uint, participant: principal }
  {
    registered-at: uint,
    attendance-status: (string-ascii 20),
    completion-score: uint,
    feedback: (string-ascii 300),
    certificate-earned: bool
  }
)

(define-map user-learning-profile
  { user: principal }
  {
    workshops-attended: uint,
    workshops-completed: uint,
    total-learning-hours: uint,
    certifications-earned: uint,
    last-activity: uint
  }
)

;; Read-only functions
(define-read-only (get-workshop-info (workshop-id uint))
  (map-get? workshops { workshop-id: workshop-id })
)

(define-read-only (get-registration-info (workshop-id uint) (participant principal))
  (map-get? workshop-registrations { workshop-id: workshop-id, participant: participant })
)

(define-read-only (get-user-learning-profile (user principal))
  (map-get? user-learning-profile { user: user })
)

(define-read-only (get-total-workshops)
  (var-get total-workshops)
)

(define-read-only (is-workshop-available (workshop-id uint))
  (match (map-get? workshops { workshop-id: workshop-id })
    workshop-data (and
      (is-eq (get status workshop-data) "scheduled")
      (< (get current-participants workshop-data) (get max-participants workshop-data))
    )
    false
  )
)

;; Public functions
(define-public (create-workshop (title (string-ascii 100)) (description (string-ascii 300)) (category (string-ascii 50)) (skill-focus (string-ascii 50)) (scheduled-date uint) (duration uint) (max-participants uint) (location (string-ascii 100)))
  (let (
    (workshop-id (var-get next-workshop-id))
  )
    (asserts! (> scheduled-date block-height) ERR_INVALID_WORKSHOP_DATA)
    (asserts! (> duration u0) ERR_INVALID_WORKSHOP_DATA)
    (asserts! (> max-participants u0) ERR_INVALID_WORKSHOP_DATA)

    (map-set workshops
      { workshop-id: workshop-id }
      {
        title: title,
        description: description,
        instructor: tx-sender,
        category: category,
        skill-focus: skill-focus,
        scheduled-date: scheduled-date,
        duration: duration,
        max-participants: max-participants,
        current-participants: u0,
        location: location,
        status: "scheduled",
        created-at: block-height
      }
    )

    (var-set next-workshop-id (+ workshop-id u1))
    (var-set total-workshops (+ (var-get total-workshops) u1))

    (ok workshop-id)
  )
)

(define-public (register-for-workshop (workshop-id uint))
  (let (
    (workshop-info (unwrap! (map-get? workshops { workshop-id: workshop-id }) ERR_WORKSHOP_NOT_FOUND))
  )
    (asserts! (is-workshop-available workshop-id) ERR_WORKSHOP_FULL)
    (asserts! (is-none (map-get? workshop-registrations { workshop-id: workshop-id, participant: tx-sender })) ERR_ALREADY_REGISTERED)

    (map-set workshop-registrations
      { workshop-id: workshop-id, participant: tx-sender }
      {
        registered-at: block-height,
        attendance-status: "registered",
        completion-score: u0,
        feedback: "",
        certificate-earned: false
      }
    )

    (map-set workshops
      { workshop-id: workshop-id }
      (merge workshop-info { current-participants: (+ (get current-participants workshop-info) u1) })
    )

    (ok true)
  )
)

(define-public (mark-attendance (workshop-id uint) (participant principal) (attendance-status (string-ascii 20)))
  (let (
    (workshop-info (unwrap! (map-get? workshops { workshop-id: workshop-id }) ERR_WORKSHOP_NOT_FOUND))
    (registration-info (unwrap! (map-get? workshop-registrations { workshop-id: workshop-id, participant: participant }) ERR_WORKSHOP_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender (get instructor workshop-info)) ERR_UNAUTHORIZED)

    (map-set workshop-registrations
      { workshop-id: workshop-id, participant: participant }
      (merge registration-info { attendance-status: attendance-status })
    )

    (ok true)
  )
)

(define-public (update-workshop-status (workshop-id uint) (new-status (string-ascii 20)))
  (let (
    (workshop-info (unwrap! (map-get? workshops { workshop-id: workshop-id }) ERR_WORKSHOP_NOT_FOUND))
  )
    (asserts! (or (is-eq tx-sender (get instructor workshop-info)) (is-eq tx-sender CONTRACT_OWNER)) ERR_UNAUTHORIZED)

    (map-set workshops
      { workshop-id: workshop-id }
      (merge workshop-info { status: new-status })
    )

    (ok true)
  )
)
