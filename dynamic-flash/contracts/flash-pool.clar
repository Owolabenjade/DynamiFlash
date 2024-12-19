;; Constants for contract configuration
(define-constant contract-owner tx-sender)
(define-constant PRECISION u10000)  ;; 4 decimal points precision for rates
(define-constant MIN-LIQUIDITY u1000000) ;; Minimum pool liquidity required
(define-constant MAX-UTILIZATION u9000)  ;; 90% maximum pool utilization
(define-constant MIN-RATE-MULTIPLIER u50)  ;; Minimum 0.5x multiplier
(define-constant MAX-RATE-MULTIPLIER u500) ;; Maximum 5x multiplier

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-INSUFFICIENT-FUNDS (err u1001))
(define-constant ERR-LOAN-IN-PROGRESS (err u1002))
(define-constant ERR-REPAYMENT-FAILED (err u1003))
(define-constant ERR-MIN-LIQUIDITY (err u1004))
(define-constant ERR-MAX-UTILIZATION (err u1005))
(define-constant ERR-INVALID-AMOUNT (err u1006))

;; Pool state variables
(define-data-var total-liquidity uint u0)
(define-data-var active-loan-amount uint u0)
(define-data-var total-loans-count uint u0)
(define-data-var total-interest-earned uint u0)

;; Interest rate parameters
(define-data-var base-rate uint u10)  ;; 0.1% base rate (10 basis points)
(define-data-var rate-multiplier uint u100)  ;; Rate increase multiplier
(define-data-var loan-in-progress bool false)

;; Interest rate governance
(define-data-var max-base-rate uint u100)  ;; 1% maximum base rate
(define-data-var min-base-rate uint u5)    ;; 0.05% minimum base rate

;; -------------------- Read-Only Functions --------------------

(define-read-only (get-pool-details)
    (ok {
        total-liquidity: (var-get total-liquidity),
        active-loan: (var-get active-loan-amount),
        total-loans: (var-get total-loans-count),
        interest-earned: (var-get total-interest-earned),
        current-rate: (get-current-interest-rate)
    }))

(define-read-only (get-current-interest-rate)
    (let (
        (utilization-rate (calculate-utilization))
        (base (var-get base-rate))
        (multiplier (var-get rate-multiplier))
    )
    (+ base (/ (* utilization-rate multiplier) PRECISION))))

(define-read-only (calculate-utilization)
    (if (is-eq (var-get total-liquidity) u0)
        u0
        (/ (* (var-get active-loan-amount) PRECISION) (var-get total-liquidity))))

(define-read-only (get-required-repayment (loan-amount uint))
    (let (
        (interest-rate (get-current-interest-rate))
        (interest-amount (/ (* loan-amount interest-rate) PRECISION))
    )
    (ok (+ loan-amount interest-amount))))

;; -------------------- Governance Functions --------------------

(define-public (update-base-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (and (>= new-rate (var-get min-base-rate)) 
                      (<= new-rate (var-get max-base-rate))) 
                 ERR-INVALID-AMOUNT)
        (ok (var-set base-rate new-rate))))

(define-public (update-rate-multiplier (new-multiplier uint))
    (begin
        ;; Check authorization
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        ;; Validate multiplier range
        (asserts! (and (>= new-multiplier MIN-RATE-MULTIPLIER)
                      (<= new-multiplier MAX-RATE-MULTIPLIER))
                 ERR-INVALID-AMOUNT)
        ;; Set new multiplier if validation passes
        (ok (var-set rate-multiplier new-multiplier))))

;; -------------------- Core Pool Functions --------------------

(define-public (deposit (amount uint))
    (begin
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        
        ;; Transfer STX to contract
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        ;; Update pool liquidity
        (var-set total-liquidity (+ (var-get total-liquidity) amount))
        
        (ok true)))

(define-public (withdraw (amount uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (<= amount (var-get total-liquidity)) ERR-INSUFFICIENT-FUNDS)
        (asserts! (>= (- (var-get total-liquidity) amount) MIN-LIQUIDITY) ERR-MIN-LIQUIDITY)
        
        ;; Transfer STX back to owner
        (try! (as-contract (stx-transfer? amount contract-owner tx-sender)))
        
        ;; Update pool liquidity
        (var-set total-liquidity (- (var-get total-liquidity) amount))
        
        (ok true)))

;; -------------------- Flash Loan Functions --------------------

(define-public (flash-loan (amount uint))
    (let (
        (current-liquidity (var-get total-liquidity))
        (utilization (calculate-utilization))
    )
        (asserts! (not (var-get loan-in-progress)) ERR-LOAN-IN-PROGRESS)
        (asserts! (>= current-liquidity amount) ERR-INSUFFICIENT-FUNDS)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (<= utilization MAX-UTILIZATION) ERR-MAX-UTILIZATION)
        
        ;; Set loan as active
        (var-set loan-in-progress true)
        (var-set active-loan-amount amount)
        
        ;; Transfer STX to borrower
        (try! (as-contract (stx-transfer? amount contract-owner tx-sender)))
        
        ;; Calculate required repayment
        (let (
            (repayment-amount (unwrap! (get-required-repayment amount) ERR-REPAYMENT-FAILED))
            (interest-earned (- repayment-amount amount))
        )
            ;; Check if borrower has sufficient balance for repayment
            (asserts! (>= (stx-get-balance tx-sender) repayment-amount) 
                     ERR-INSUFFICIENT-FUNDS)
            
            ;; Process repayment
            (try! (stx-transfer? repayment-amount tx-sender (as-contract tx-sender)))
            
            ;; Update contract state
            (var-set total-loans-count (+ (var-get total-loans-count) u1))
            (var-set total-interest-earned (+ (var-get total-interest-earned) interest-earned))
            (var-set loan-in-progress false)
            (var-set active-loan-amount u0)
            
            (ok repayment-amount))))

;; -------------------- Emergency Functions --------------------

(define-public (emergency-shutdown)
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (var-set loan-in-progress false)
        (var-set active-loan-amount u0)
        (ok true)))

;; -------------------- Events --------------------

(define-data-var last-event-nonce uint u0)

(define-read-only (get-last-event-nonce) 
    (ok (var-get last-event-nonce)))

(define-private (emit-flash-loan-event (borrower principal) (amount uint) (interest uint))
    (begin
        (var-set last-event-nonce (+ (var-get last-event-nonce) u1))
        (print {
            event: "flash-loan",
            nonce: (var-get last-event-nonce),
            borrower: borrower,
            amount: amount,
            interest: interest,
            timestamp: block-height
        })))