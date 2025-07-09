;; Harvest Distribution Contract
;; Manages produce sharing among community garden participants

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_HARVEST_NOT_FOUND (err u301))
(define-constant ERR_INVALID_CONTRIBUTION (err u305))

;; Data Variables
(define-data-var next-harvest-id uint u1)
(define-data-var total-harvests uint u0)
(define-data-var community-pool-balance uint u0)

;; Data Maps
(define-map harvests
  { harvest-id: uint }
  {
    contributor: principal,
    crop-type: (string-ascii 50),
    quantity: uint,
    quality-grade: (string-ascii 20),
    harvest-date: uint,
    plot-id: uint,
    shared-percentage: uint,
    status: (string-ascii 20),
    notes: (string-ascii 200)
  }
)

(define-map user-contributions
  { user: principal, season: uint }
  {
    total-contributed: uint,
    total-received: uint,
    contribution-score: uint,
    harvest-count: uint
  }
)

(define-map crop-inventory
  { crop-type: (string-ascii 50) }
  {
    total-quantity: uint,
    available-quantity: uint,
    last-harvest: uint,
    harvest-count: uint
  }
)

;; Read-only functions
(define-read-only (get-harvest-info (harvest-id uint))
  (map-get? harvests { harvest-id: harvest-id })
)

(define-read-only (get-user-contributions (user principal) (season uint))
  (map-get? user-contributions { user: user, season: season })
)

(define-read-only (get-crop-inventory (crop-type (string-ascii 50)))
  (map-get? crop-inventory { crop-type: crop-type })
)

(define-read-only (get-community-pool-balance)
  (var-get community-pool-balance)
)

(define-read-only (get-total-harvests)
  (var-get total-harvests)
)

;; Public functions
(define-public (record-harvest (crop-type (string-ascii 50)) (quantity uint) (quality-grade (string-ascii 20)) (plot-id uint) (shared-percentage uint) (notes (string-ascii 200)))
  (let (
    (harvest-id (var-get next-harvest-id))
    (current-season (/ block-height u2016))
  )
    (asserts! (> quantity u0) ERR_INVALID_CONTRIBUTION)
    (asserts! (<= shared-percentage u100) ERR_INVALID_CONTRIBUTION)

    (map-set harvests
      { harvest-id: harvest-id }
      {
        contributor: tx-sender,
        crop-type: crop-type,
        quantity: quantity,
        quality-grade: quality-grade,
        harvest-date: block-height,
        plot-id: plot-id,
        shared-percentage: shared-percentage,
        status: "recorded",
        notes: notes
      }
    )

    ;; Update user contributions
    (let (
      (current-data (default-to
        { total-contributed: u0, total-received: u0, contribution-score: u0, harvest-count: u0 }
        (map-get? user-contributions { user: tx-sender, season: current-season })))
    )
      (map-set user-contributions
        { user: tx-sender, season: current-season }
        {
          total-contributed: (+ (get total-contributed current-data) quantity),
          total-received: (get total-received current-data),
          contribution-score: (+ (get contribution-score current-data) (/ quantity u100)),
          harvest-count: (+ (get harvest-count current-data) u1)
        }
      )
    )

    ;; Update crop inventory
    (let (
      (current-inventory (default-to
        { total-quantity: u0, available-quantity: u0, last-harvest: u0, harvest-count: u0 }
        (map-get? crop-inventory { crop-type: crop-type })))
    )
      (map-set crop-inventory
        { crop-type: crop-type }
        {
          total-quantity: (+ (get total-quantity current-inventory) quantity),
          available-quantity: (+ (get available-quantity current-inventory) quantity),
          last-harvest: block-height,
          harvest-count: (+ (get harvest-count current-inventory) u1)
        }
      )
    )

    ;; Add shared portion to community pool
    (let ((shared-quantity (/ (* quantity shared-percentage) u100)))
      (var-set community-pool-balance (+ (var-get community-pool-balance) shared-quantity))
    )

    (var-set next-harvest-id (+ harvest-id u1))
    (var-set total-harvests (+ (var-get total-harvests) u1))

    (ok harvest-id)
  )
)

(define-public (donate-to-community-pool (crop-type (string-ascii 50)) (quantity uint))
  (let (
    (current-season (/ block-height u2016))
  )
    (asserts! (> quantity u0) ERR_INVALID_CONTRIBUTION)

    (var-set community-pool-balance (+ (var-get community-pool-balance) quantity))

    (ok true)
  )
)

(define-public (update-harvest-status (harvest-id uint) (new-status (string-ascii 20)))
  (let (
    (harvest-info (unwrap! (map-get? harvests { harvest-id: harvest-id }) ERR_HARVEST_NOT_FOUND))
  )
    (asserts! (or (is-eq tx-sender (get contributor harvest-info)) (is-eq tx-sender CONTRACT_OWNER)) ERR_UNAUTHORIZED)

    (map-set harvests
      { harvest-id: harvest-id }
      (merge harvest-info { status: new-status })
    )

    (ok true)
  )
)
