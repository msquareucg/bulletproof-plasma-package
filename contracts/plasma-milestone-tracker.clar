;; Plasma Milestone Tracker
;;
;; A blockchain-based achievement tracking system for learning progression.
;; This contract enables decentralized milestone verification and tracking
;; using a secure, immutable plasma-inspired architecture.

;; =============================
;; Constants & Error Codes
;; =============================
(define-constant CONTRACT-OWNER tx-sender)
;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-USER-NOT-FOUND (err u201))
(define-constant ERR-MILESTONE-NOT-FOUND (err u202))
(define-constant ERR-MILESTONE-ALREADY-EXISTS (err u203))
(define-constant ERR-PLASMA-NETWORK-NOT-FOUND (err u204))
(define-constant ERR-PLASMA-NETWORK-ALREADY-EXISTS (err u205))
(define-constant ERR-PARENT-MILESTONE-NOT-FOUND (err u206))
(define-constant ERR-MILESTONE-ALREADY-COMPLETED (err u207))
(define-constant ERR-PREREQUISITES-NOT-COMPLETED (err u208))
(define-constant ERR-INVALID-PARAMETERS (err u209))
(define-constant ERR-INVALID-USER-ROLE (err u210))
(define-constant ERR-NODE-NOT-REGISTERED (err u211))
(define-constant ERR-DUPLICATE-RELATIONSHIP (err u212))

;; =============================
;; Data Maps & Variables
;; =============================
;; User roles: 1=Admin, 2=Plasma Researcher, 3=Mentor, 4=Learner
(define-map users
  { user-id: principal }
  {
    role: uint,
    name: (string-ascii 100),
    registered-at: uint,
  }
)

;; Stores relationships between users in plasma network
(define-map user-connections
  {
    user-id: principal,
    connected-user-id: principal,
  }
  { connection-type: (string-ascii 20) } ;; "mentor-learner" or "researcher-learner"
)

;; Plasma networks represent collections of milestone graphs
(define-map plasma-networks
  { network-id: uint }
  {
    name: (string-ascii 100),
    description: (string-ascii 500),
    created-by: principal,
    created-at: uint,
  }
)

;; Milestone definitions in plasma-inspired tracking
(define-map milestones
  { milestone-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    category: (string-ascii 50),
    complexity-level: uint, ;; 1-5 representing complexity
    network-id: uint,
    parent-milestone-id: (optional uint),
    created-by: principal,
    created-at: uint,
  }
)

;; Tracks milestone progression and verification
(define-map milestone-progressions
  {
    milestone-id: uint,
    user-id: principal,
  }
  {
    progression-timestamp: uint,
    verified-by: principal,
    evidence-link: (optional (string-utf8 500)),
  }
)

;; Milestone prerequisites for structured learning
(define-map milestone-dependencies
  {
    milestone-id: uint,
    dependency-id: uint,
  }
  { added-at: uint }
)

;; Counters for milestone and network generation
(define-data-var milestone-id-counter uint u1)
(define-data-var network-id-counter uint u1)

;; =============================
;; Private Functions
;; =============================
;; Validate user's authorization in plasma network
(define-private (can-manage-connection
    (manager-id principal)
    (learner-id principal)
  )
  (or
    (is-eq manager-id CONTRACT-OWNER)
    (match (map-get? user-connections {
      user-id: manager-id,
      connected-user-id: learner-id,
    })
      connection
      true
      false
    )
  )
)

;; Generate next milestone identifier
(define-private (get-next-milestone-id)
  (let ((next-id (var-get milestone-id-counter)))
    (var-set milestone-id-counter (+ next-id u1))
    next-id
  )
)

;; Generate next plasma network identifier
(define-private (get-next-network-id)
  (let ((next-id (var-get network-id-counter)))
    (var-set network-id-counter (+ next-id u1))
    next-id
  )
)

;; =============================
;; Read-Only Functions
;; =============================
;; Retrieve user profile
(define-read-only (get-user (user-id principal))
  (map-get? users { user-id: user-id })
)

;; Retrieve milestone details
(define-read-only (get-milestone (milestone-id uint))
  (map-get? milestones { milestone-id: milestone-id })
)

;; Retrieve plasma network information
(define-read-only (get-plasma-network (network-id uint))
  (map-get? plasma-networks { network-id: network-id })
)

;; Check milestone progression status
(define-read-only (is-milestone-progressed
    (milestone-id uint)
    (user-id principal)
  )
  (is-some (map-get? milestone-progressions {
    milestone-id: milestone-id,
    user-id: user-id,
  }))
)

;; Retrieve milestone progression details
(define-read-only (get-milestone-progression
    (milestone-id uint)
    (user-id principal)
  )
  (map-get? milestone-progressions {
    milestone-id: milestone-id,
    user-id: user-id,
  })
)

;; =============================
;; Public Functions
;; =============================
;; User registration in plasma network
(define-public (register-user
    (name (string-ascii 100))
    (role uint)
  )
  (let ((user-id tx-sender))
    (asserts! (and (>= role u1) (<= role u4)) ERR-INVALID-USER-ROLE)
    (asserts! (is-none (map-get? users { user-id: user-id }))
      ERR-MILESTONE-ALREADY-EXISTS
    )
    (map-set users { user-id: user-id } {
      role: role,
      name: name,
      registered-at: block-height,
    })
    (ok true)
  )
)

;; Create milestone in plasma network
(define-public (create-milestone
    (title (string-ascii 100))
    (description (string-ascii 500))
    (category (string-ascii 50))
    (complexity-level uint)
    (network-id uint)
    (parent-milestone-id (optional uint))
  )
  (let (
      (user-id tx-sender)
      (milestone-id (get-next-milestone-id))
    )
    ;; Validate plasma network
    (asserts! (is-some (map-get? plasma-networks { network-id: network-id }))
      ERR-PLASMA-NETWORK-NOT-FOUND
    )
    ;; Validate complexity level
    (asserts! (and (>= complexity-level u1) (<= complexity-level u5))
      ERR-INVALID-PARAMETERS
    )
    ;; Validate parent milestone if specified
    (asserts!
      (match parent-milestone-id
        parent-id (is-some (map-get? milestones { milestone-id: parent-id }))
        true
      )
      ERR-PARENT-MILESTONE-NOT-FOUND
    )
    (map-set milestones { milestone-id: milestone-id } {
      title: title,
      description: description,
      category: category,
      complexity-level: complexity-level,
      network-id: network-id,
      parent-milestone-id: parent-milestone-id,
      created-by: user-id,
      created-at: block-height,
    })
    (ok milestone-id)
  )
)
)