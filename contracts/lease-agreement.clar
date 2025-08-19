;; Pop-up Retail Lease Agreement Contract
;; Manages lease agreements, payments, and terms for temporary retail spaces

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-LEASE-NOT-FOUND (err u201))
(define-constant ERR-LEASE-ALREADY-EXISTS (err u202))
(define-constant ERR-INVALID-INPUT (err u203))
(define-constant ERR-LEASE-EXPIRED (err u204))
(define-constant ERR-LEASE-ACTIVE (err u205))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u206))
(define-constant ERR-PAYMENT-ALREADY-MADE (err u207))
(define-constant ERR-LEASE-NOT-ACTIVE (err u208))
(define-constant ERR-EARLY-TERMINATION-FEE (err u209))

;; Lease status constants
(define-constant STATUS-PENDING u1)
(define-constant STATUS-ACTIVE u2)
(define-constant STATUS-COMPLETED u3)
(define-constant STATUS-TERMINATED u4)
(define-constant STATUS-CANCELLED u5)

;; Payment status constants
(define-constant PAYMENT-PENDING u1)
(define-constant PAYMENT-PAID u2)
(define-constant PAYMENT-OVERDUE u3)

;; Data Variables
(define-data-var next-lease-id uint u1)
(define-data-var total-leases uint u0)
(define-data-var platform-fee-percentage uint u5) ;; 5% platform fee

;; Data Maps
(define-map leases
  { lease-id: uint }
  {
    venue-id: uint,
    tenant: principal,
    landlord: principal,
    start-date: uint,
    end-date: uint,
    daily-rate: uint,
    total-amount: uint,
    security-deposit: uint,
    status: uint,
    created-at: uint,
    signed-at: (optional uint),
    terminated-at: (optional uint),
    terms: (string-ascii 1000),
    early-termination-fee: uint
  }
)

(define-map lease-payments
  { lease-id: uint, payment-period: uint }
  {
    amount-due: uint,
    amount-paid: uint,
    due-date: uint,
    paid-date: (optional uint),
    status: uint,
    late-fee: uint
  }
)

(define-map tenant-history
  { tenant: principal }
  {
    total-leases: uint,
    active-leases: uint,
    total-paid: uint,
    reputation-score: uint,
    late-payments: uint
  }
)

(define-map landlord-earnings
  { landlord: principal }
  {
    total-earnings: uint,
    active-leases: uint,
    completed-leases: uint,
    average-rating: uint
  }
)

(define-map authorized-managers
  { manager: principal }
  { authorized: bool }
)

;; Authorization Functions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-lease-party (lease-id uint))
  (match (map-get? leases { lease-id: lease-id })
    lease-data (or (is-eq tx-sender (get tenant lease-data))
                   (is-eq tx-sender (get landlord lease-data)))
    false
  )
)

(define-private (is-authorized-manager)
  (default-to false (get authorized (map-get? authorized-managers { manager: tx-sender })))
)

(define-private (can-manage-lease (lease-id uint))
  (or (is-contract-owner) (is-lease-party lease-id) (is-authorized-manager))
)

;; Helper Functions
(define-private (calculate-lease-duration (start-date uint) (end-date uint))
  (if (> end-date start-date)
    (- end-date start-date)
    u0
  )
)

(define-private (calculate-total-amount (daily-rate uint) (duration-days uint))
  (* daily-rate duration-days)
)

(define-private (calculate-security-deposit (total-amount uint))
  (/ (* total-amount u20) u100) ;; 20% of total amount
)

(define-private (is-lease-expired (lease-id uint))
  (match (map-get? leases { lease-id: lease-id })
    lease-data (> block-height (get end-date lease-data))
    true
  )
)

;; Public Functions

;; Create a new lease agreement
(define-public (create-lease (venue-id uint) (tenant principal) (landlord principal) (start-date uint) (end-date uint) (daily-rate uint) (terms (string-ascii 1000)))
  (let
    (
      (lease-id (var-get next-lease-id))
      (duration-days (calculate-lease-duration start-date end-date))
      (total-amount (calculate-total-amount daily-rate duration-days))
      (security-deposit (calculate-security-deposit total-amount))
      (early-termination-fee (/ total-amount u4)) ;; 25% of total amount
    )
    (asserts! (> venue-id u0) ERR-INVALID-INPUT)
    (asserts! (not (is-eq tenant landlord)) ERR-INVALID-INPUT)
    (asserts! (> end-date start-date) ERR-INVALID-INPUT)
    (asserts! (> daily-rate u0) ERR-INVALID-INPUT)
    (asserts! (> duration-days u0) ERR-INVALID-INPUT)
    (asserts! (<= duration-days u365) ERR-INVALID-INPUT) ;; Max 1 year lease

    ;; Create lease record
    (map-set leases
      { lease-id: lease-id }
      {
        venue-id: venue-id,
        tenant: tenant,
        landlord: landlord,
        start-date: start-date,
        end-date: end-date,
        daily-rate: daily-rate,
        total-amount: total-amount,
        security-deposit: security-deposit,
        status: STATUS-PENDING,
        created-at: block-height,
        signed-at: none,
        terminated-at: none,
        terms: terms,
        early-termination-fee: early-termination-fee
      }
    )

    ;; Initialize first payment period
    (map-set lease-payments
      { lease-id: lease-id, payment-period: u1 }
      {
        amount-due: (+ total-amount security-deposit),
        amount-paid: u0,
        due-date: start-date,
        paid-date: none,
        status: PAYMENT-PENDING,
        late-fee: u0
      }
    )

    ;; Update contract state
    (var-set next-lease-id (+ lease-id u1))
    (var-set total-leases (+ (var-get total-leases) u1))

    (ok lease-id)
  )
)

;; Sign and activate lease
(define-public (sign-lease (lease-id uint))
  (let
    (
      (lease-data (unwrap! (map-get? leases { lease-id: lease-id }) ERR-LEASE-NOT-FOUND))
    )
    (asserts! (is-lease-party lease-id) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status lease-data) STATUS-PENDING) ERR-LEASE-ACTIVE)

    (map-set leases
      { lease-id: lease-id }
      (merge lease-data {
        status: STATUS-ACTIVE,
        signed-at: (some block-height)
      })
    )

    ;; Update tenant history
    (match (map-get? tenant-history { tenant: (get tenant lease-data) })
      existing-history
        (map-set tenant-history
          { tenant: (get tenant lease-data) }
          (merge existing-history {
            total-leases: (+ (get total-leases existing-history) u1),
            active-leases: (+ (get active-leases existing-history) u1)
          })
        )
      (map-set tenant-history
        { tenant: (get tenant lease-data) }
        {
          total-leases: u1,
          active-leases: u1,
          total-paid: u0,
          reputation-score: u75, ;; Default score
          late-payments: u0
        }
      )
    )

    ;; Update landlord earnings
    (match (map-get? landlord-earnings { landlord: (get landlord lease-data) })
      existing-earnings
        (map-set landlord-earnings
          { landlord: (get landlord lease-data) }
          (merge existing-earnings {
            active-leases: (+ (get active-leases existing-earnings) u1)
          })
        )
      (map-set landlord-earnings
        { landlord: (get landlord lease-data) }
        {
          total-earnings: u0,
          active-leases: u1,
          completed-leases: u0,
          average-rating: u75
        }
      )
    )

    (ok true)
  )
)

;; Process lease payment
(define-public (make-payment (lease-id uint) (payment-period uint) (amount uint))
  (let
    (
      (lease-data (unwrap! (map-get? leases { lease-id: lease-id }) ERR-LEASE-NOT-FOUND))
      (payment-data (unwrap! (map-get? lease-payments { lease-id: lease-id, payment-period: payment-period }) ERR-LEASE-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get tenant lease-data)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status lease-data) STATUS-ACTIVE) ERR-LEASE-NOT-ACTIVE)
    (asserts! (>= amount (get amount-due payment-data)) ERR-INSUFFICIENT-PAYMENT)
    (asserts! (is-eq (get status payment-data) PAYMENT-PENDING) ERR-PAYMENT-ALREADY-MADE)

    ;; Calculate late fee if payment is overdue
    (let
      (
        (late-fee (if (> block-height (get due-date payment-data))
                    (/ (get amount-due payment-data) u20) ;; 5% late fee
                    u0))
        (total-payment (+ amount late-fee))
      )

      ;; Update payment record
      (map-set lease-payments
        { lease-id: lease-id, payment-period: payment-period }
        (merge payment-data {
          amount-paid: total-payment,
          paid-date: (some block-height),
          status: PAYMENT-PAID,
          late-fee: late-fee
        })
      )

      ;; Update tenant history
      (match (map-get? tenant-history { tenant: (get tenant lease-data) })
        tenant-data
          (map-set tenant-history
            { tenant: (get tenant lease-data) }
            (merge tenant-data {
              total-paid: (+ (get total-paid tenant-data) total-payment),
              late-payments: (if (> late-fee u0)
                              (+ (get late-payments tenant-data) u1)
                              (get late-payments tenant-data))
            })
          )
        false ;; Should not happen
      )

      ;; Update landlord earnings
      (let
        (
          (platform-fee (/ (* total-payment (var-get platform-fee-percentage)) u100))
          (landlord-amount (- total-payment platform-fee))
        )
        (match (map-get? landlord-earnings { landlord: (get landlord lease-data) })
          earnings-data
            (map-set landlord-earnings
              { landlord: (get landlord lease-data) }
              (merge earnings-data {
                total-earnings: (+ (get total-earnings earnings-data) landlord-amount)
              })
            )
          false ;; Should not happen
        )
      )

      (ok total-payment)
    )
  )
)

;; Terminate lease early
(define-public (terminate-lease (lease-id uint) (reason (string-ascii 200)))
  (let
    (
      (lease-data (unwrap! (map-get? leases { lease-id: lease-id }) ERR-LEASE-NOT-FOUND))
    )
    (asserts! (is-lease-party lease-id) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status lease-data) STATUS-ACTIVE) ERR-LEASE-NOT-ACTIVE)
    (asserts! (not (is-lease-expired lease-id)) ERR-LEASE-EXPIRED)

    ;; Check if early termination fee needs to be paid
    (let
      (
        (remaining-days (- (get end-date lease-data) block-height))
        (early-termination-fee (get early-termination-fee lease-data))
      )
      (asserts! (>= remaining-days u7) ERR-EARLY-TERMINATION-FEE) ;; Must give 7 days notice

      (map-set leases
        { lease-id: lease-id }
        (merge lease-data {
          status: STATUS-TERMINATED,
          terminated-at: (some block-height)
        })
      )

      ;; Update tenant active leases count
      (match (map-get? tenant-history { tenant: (get tenant lease-data) })
        tenant-data
          (map-set tenant-history
            { tenant: (get tenant lease-data) }
            (merge tenant-data {
              active-leases: (- (get active-leases tenant-data) u1)
            })
          )
        false
      )

      ;; Update landlord active leases count
      (match (map-get? landlord-earnings { landlord: (get landlord lease-data) })
        earnings-data
          (map-set landlord-earnings
            { landlord: (get landlord lease-data) }
            (merge earnings-data {
              active-leases: (- (get active-leases earnings-data) u1),
              completed-leases: (+ (get completed-leases earnings-data) u1)
            })
          )
        false
      )

      (ok early-termination-fee)
    )
  )
)

;; Complete lease naturally
(define-public (complete-lease (lease-id uint))
  (let
    (
      (lease-data (unwrap! (map-get? leases { lease-id: lease-id }) ERR-LEASE-NOT-FOUND))
    )
    (asserts! (can-manage-lease lease-id) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status lease-data) STATUS-ACTIVE) ERR-LEASE-NOT-ACTIVE)
    (asserts! (is-lease-expired lease-id) ERR-LEASE-ACTIVE)

    (map-set leases
      { lease-id: lease-id }
      (merge lease-data { status: STATUS-COMPLETED })
    )

    ;; Update tenant history
    (match (map-get? tenant-history { tenant: (get tenant lease-data) })
      tenant-data
        (map-set tenant-history
          { tenant: (get tenant lease-data) }
          (merge tenant-data {
            active-leases: (- (get active-leases tenant-data) u1)
          })
        )
      false
    )

    ;; Update landlord earnings
    (match (map-get? landlord-earnings { landlord: (get landlord lease-data) })
      earnings-data
        (map-set landlord-earnings
          { landlord: (get landlord lease-data) }
          (merge earnings-data {
            active-leases: (- (get active-leases earnings-data) u1),
            completed-leases: (+ (get completed-leases earnings-data) u1)
          })
        )
      false
    )

    (ok true)
  )
)

;; Administrative Functions

;; Authorize manager
(define-public (authorize-manager (manager principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (map-set authorized-managers { manager: manager } { authorized: true })
    (ok true)
  )
)

;; Update platform fee
(define-public (update-platform-fee (new-fee-percentage uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee-percentage u20) ERR-INVALID-INPUT) ;; Max 20% fee
    (var-set platform-fee-percentage new-fee-percentage)
    (ok true)
  )
)

;; Read-only Functions

;; Get lease information
(define-read-only (get-lease-info (lease-id uint))
  (map-get? leases { lease-id: lease-id })
)

;; Get payment information
(define-read-only (get-payment-info (lease-id uint) (payment-period uint))
  (map-get? lease-payments { lease-id: lease-id, payment-period: payment-period })
)

;; Get tenant history
(define-read-only (get-tenant-history (tenant principal))
  (map-get? tenant-history { tenant: tenant })
)

;; Get landlord earnings
(define-read-only (get-landlord-earnings (landlord principal))
  (map-get? landlord-earnings { landlord: landlord })
)

;; Check if lease is active
(define-read-only (is-lease-active (lease-id uint))
  (match (map-get? leases { lease-id: lease-id })
    lease-data (is-eq (get status lease-data) STATUS-ACTIVE)
    false
  )
)

;; Get total leases
(define-read-only (get-total-leases)
  (var-get total-leases)
)

;; Get platform fee percentage
(define-read-only (get-platform-fee-percentage)
  (var-get platform-fee-percentage)
)

;; Calculate remaining lease days
(define-read-only (get-remaining-lease-days (lease-id uint))
  (match (map-get? leases { lease-id: lease-id })
    lease-data
      (if (> (get end-date lease-data) block-height)
        (some (- (get end-date lease-data) block-height))
        (some u0))
    none
  )
)
