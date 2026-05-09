# Coin Economy Merchant Seller v1

Branch: `coin-economy-merchant-seller-v1`

This branch adds a real MVP coin ledger for internal testing.

## Main rule

Users have different coin balance types:

```txt
consumable       = user can spend these coins later on gifts/store/games
merchant_supply = merchant business supply, can send to users, cannot consume directly
seller_supply   = coin seller/reseller business supply, can send to users, cannot consume directly
founder_supply  = platform supply source used by Founder/Owner grant actions
```

Merchant and seller accounts cannot use their supply coins for direct consumption. They must send coins to a user, and the receiver gets `consumable` coins.

## New tables

```txt
coin_balances
coin_transactions
```

## New APIs

```txt
GET  /coin-economy/balance-types
GET  /coin-economy/wallet/me
GET  /coin-economy/wallet/user/{public_user_id}
POST /coin-economy/super-owner/grant
POST /coin-economy/merchant/send-to-user
POST /coin-economy/seller/send-to-user
POST /coin-economy/consume
GET  /coin-economy/transactions/me
```

## Beginner test flow

### 1. Checkout branch

```powershell
cd "D:\Vibe Match\vibematch"
git fetch
git checkout coin-economy-merchant-seller-v1
```

### 2. Start backend

```powershell
docker compose up -d
cd backend
.\.venv\Scripts\activate
uvicorn app.main:app --reload
```

Open:

```txt
http://127.0.0.1:8000/docs
```

### 3. Create test accounts

Run:

```txt
GET /internal-test/multi-device/accounts
```

Copy:

- Founder token
- User A public_user_id
- User B public_user_id

### 4. Promote User A to merchant

Authorize Swagger using Founder token:

```txt
Bearer FOUNDER_ACCESS_TOKEN
```

Run:

```txt
POST /internal-test/multi-device/promote
```

Body:

```json
{
  "public_user_id": USER_A_PUBLIC_ID,
  "role": "merchant",
  "reason": "Make User A merchant for coin economy test"
}
```

### 5. Promote User B to coin seller

Run:

```txt
POST /internal-test/multi-device/promote
```

Body:

```json
{
  "public_user_id": USER_B_PUBLIC_ID,
  "role": "coin_seller",
  "reason": "Make User B seller for coin economy test"
}
```

### 6. Founder sends supply to merchant

Still authorized as Founder, run:

```txt
POST /coin-economy/super-owner/grant
```

Body:

```json
{
  "target_public_user_id": USER_A_PUBLIC_ID,
  "amount": 10000,
  "target_balance_type": "merchant_supply",
  "reason": "Founder supply to merchant for internal testing"
}
```

### 7. Founder sends supply to seller

```txt
POST /coin-economy/super-owner/grant
```

Body:

```json
{
  "target_public_user_id": USER_B_PUBLIC_ID,
  "amount": 5000,
  "target_balance_type": "seller_supply",
  "reason": "Founder supply to seller for internal testing"
}
```

### 8. Merchant sends coins to a normal user

Login/authorize as User A merchant.

Run:

```txt
POST /coin-economy/merchant/send-to-user
```

Body:

```json
{
  "target_public_user_id": USER_B_PUBLIC_ID,
  "amount": 1000,
  "reason": "Merchant sends consumable coins to user"
}
```

This deducts User A `merchant_supply` and adds User B `consumable` coins.

### 9. Seller sends coins to a normal user

Login/authorize as User B seller.

Run:

```txt
POST /coin-economy/seller/send-to-user
```

Body:

```json
{
  "target_public_user_id": USER_A_PUBLIC_ID,
  "amount": 500,
  "reason": "Seller sends consumable coins to user"
}
```

This deducts User B `seller_supply` and adds User A `consumable` coins.

### 10. Verify wallets

Run:

```txt
GET /coin-economy/wallet/user/{public_user_id}
```

Check:

- merchant_supply decreased after merchant send
- seller_supply decreased after seller send
- consumable increased for receiving user

### 11. Test direct consumption block rule

If merchant has only `merchant_supply` and zero `consumable`, run as merchant:

```txt
POST /coin-economy/consume
```

Body:

```json
{
  "amount": 100,
  "reason": "Try spending business supply directly"
}
```

Expected result:

```txt
Insufficient consumable coins
```

That confirms merchant/seller supply cannot be spent directly.

## Notes

- This is an MVP internal ledger, not the final production payment system.
- Later we need balance locking, settlement reports, merchant KYC, fraud rules, and payout/recharge reconciliation.
- Do not expose internal test role APIs in production.
