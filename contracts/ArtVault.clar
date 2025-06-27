;; ArtVault - Digital art authenticity certification platform

(define-non-fungible-token art-certificate uint)

;; Storage
(define-map certificate-registry uint {artist: principal, artwork-title: (string-utf8 64), creation-date: (string-utf8 256), authenticity-proof: (string-utf8 256), market-price: uint})
(define-data-var certificate-id-counter uint u0)

;; Error codes
(define-constant err-artist-only (err u500))
(define-constant err-certificate-not-found (err u501))
(define-constant err-purchase-failed (err u502))
(define-constant err-invalid-title (err u503))
(define-constant err-invalid-date (err u504))
(define-constant err-invalid-proof (err u505))
(define-constant err-invalid-price (err u506))
(define-constant err-invalid-certificate-id (err u507))

;; Issue art certificate
(define-public (issue-certificate (artwork-title (string-utf8 64)) (creation-date (string-utf8 256)) (authenticity-proof (string-utf8 256)) (market-price uint))
  (begin
    ;; Validate certificate parameters
    (asserts! (> (len artwork-title) u0) err-invalid-title)
    (asserts! (> (len creation-date) u0) err-invalid-date)
    (asserts! (> (len authenticity-proof) u0) err-invalid-proof)
    (asserts! (> market-price u0) err-invalid-price)
    
    (let
      ((certificate-id (var-get certificate-id-counter))
       (artist tx-sender))
      
      ;; Mint certificate NFT
      (try! (nft-mint? art-certificate certificate-id artist))
      
      ;; Register certificate details
      (map-set certificate-registry certificate-id {artist: artist, artwork-title: artwork-title, creation-date: creation-date, authenticity-proof: authenticity-proof, market-price: market-price})
      
      ;; Increment certificate counter
      (var-set certificate-id-counter (+ certificate-id u1))
      
      (ok certificate-id))))

;; Purchase certificate
(define-public (purchase-certificate (certificate-id uint))
  (begin
    ;; Validate certificate ID
    (asserts! (< certificate-id (var-get certificate-id-counter)) err-invalid-certificate-id)
    
    (let
      ((certificate-data (unwrap! (map-get? certificate-registry certificate-id) err-certificate-not-found))
       (price (get market-price certificate-data))
       (artist (get artist certificate-data))
       (current-owner (unwrap! (nft-get-owner? art-certificate certificate-id) err-certificate-not-found)))
      
      ;; Check buyer has sufficient funds
      (asserts! (>= (stx-get-balance tx-sender) price) err-purchase-failed)
      
      ;; Transfer payment to artist
      (try! (stx-transfer? price tx-sender artist))
      
      ;; Transfer certificate to buyer
      (try! (nft-transfer? art-certificate certificate-id current-owner tx-sender))
      
      (ok true))))

;; Get certificate details
(define-read-only (get-certificate-details (certificate-id uint))
  (map-get? certificate-registry certificate-id))

;; Check certificate ownership
(define-read-only (owns-certificate (certificate-id uint) (collector principal))
  (is-eq (some collector) (nft-get-owner? art-certificate certificate-id)))

;; Get certificate owner
(define-read-only (get-certificate-owner (certificate-id uint))
  (nft-get-owner? art-certificate certificate-id))