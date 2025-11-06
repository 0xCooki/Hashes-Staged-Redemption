# Hashes Staged Redemption Contract

The Redemption contract manages a three-stage redemption system that allows eligible Hashes NFT holders to redeem their tokens for ETH. During the first phase, the contract owner (or anyone) can send ETH to the contract. In the second and third phases, users with eligible Hashes NFTs can claim their share of the redemption amount. When users redeem their eligible Hashes NFTs, they are transferred from the user to the redemption contract. The redemption value in the second phase is determined by the ETH deposited divided by the number of eligible hashes NFTs. Whereas the redemption value in the final phase is set by the remaining ETH that was not redeemed in the second phase, divided by the number of redeemers. 

Built with [Foundry](https://book.getfoundry.sh/) and Openzeppelin v4.9.0

### Contract Overview

The Redemption contract operates in three distinct stages:

1. **PreRedemption Stage**: Redemptions disabled, ETH deposits enabled
2. **Redemption Stage**: First redemption enabled, ETH deposits enabled
3. **PostRedemption Stage**: Second redemption enabled, ETH deposits disabled

### Key Contract Parameters

- **INITIAL_ELIGIBLE_HASHES_TOTAL**: 579 - The initial number of Hashes tokens eligible for redemption
- **MIN_REDEMPTION_TIME**: 180 days - Minimum time required before moving to PostRedemption stage
- **Eligibility Criteria**: A Hashes token is eligible if:
  - Token ID is less than 1000
  - Token is not in the excluded list (set during contract deployment)

### Contract Functions

| Function | Owner | Any User | Description |
|----------|-------|----------|-------------|
| deposit() | | ✓ | Deposit ETH into the contract (PreRedemption and Redemption stages only) |
| redeem() | | ✓ | Redeem eligible Hashes tokens for ETH |
| setRedemptionStage() | ✓ | | Move contract from PreRedemption to Redemption stage |
| setPostRedemptionStage() | ✓ | | Move contract from Redemption to PostRedemption stage (requires 180 days minimum) |
| recoverERC20() | ✓ | | Recover ERC20 tokens sent to the contract |
| isHashEligibleForRedemption() | | ✓ | Check if a specific token ID is eligible for redemption |

### User Redemption Journey

#### Stage 1: PreRedemption

**What Happens:**
- The contract is deployed and starts in the PreRedemption stage
- Anyone can deposit ETH into the contract using the `deposit()` function or by sending ETH directly
- Deposits are tracked via events but no redemptions are allowed yet
- The owner can move to the Redemption stage at any time by calling `setRedemptionStage()`

**User Actions:**
- Users can deposit ETH if they wish to contribute to the redemption pool
- Users should verify their Hashes tokens are eligible using `isHashEligibleForRedemption(tokenId)`
- Users must wait for the owner to transition to the Redemption stage

#### Stage 2: Redemption

**What Happens:**
- When the owner calls `setRedemptionStage()`, the contract:
  - Calculates `redemptionPerHash = contractBalance / 579` (initial eligible total)
  - Records the current timestamp for the minimum redemption period
  - Allows users to redeem their eligible Hashes tokens
- **Continued Deposits**: The owner or anyone else can continue to deposit ETH into the contract during the Redemption stage using the `deposit()` function or by sending ETH directly. These additional deposits increase the contract balance, but the `redemptionPerHash` value is fixed at the start of the Redemption stage and does not change until PostRedemption. This means all redemptions during Stage 2 use the same fixed rate, regardless of when additional deposits are made. The additional ETH will be available for distribution in the PostRedemption stage.

**User Actions:**
1. Set approval for the redemption contract to transfer NFTs by calling `setApprovalForAll(redemptionContractAddress, true)` on the Hashes contract
2. Call `redeem()` function while holding eligible Hashes tokens
3. The contract will:
   - Iterate through all tokens owned by the user
   - Check each token's eligibility (tokenId < 1000 and not excluded)
   - Transfer eligible Hashes NFTs from the user to the contract
   - Mark eligible tokens as redeemed (preventing double redemption)
   - Count the number of eligible tokens redeemed
   - Transfer ETH: `eligibleTokensCount × redemptionPerHash`
   - Record the count in `amountRedeemed[user]` for PostRedemption claims

**Example:**
- Contract has 100 ETH deposited
- `redemptionPerHash = 100 ETH / 579 = ~0.1729 ETH per token`
- User redeems 5 eligible tokens
- User receives: `5 × 0.1729 ETH = ~0.8645 ETH`
- `amountRedeemed[user] = 5` (stored for PostRedemption stage)

**Important Notes:**
- Users can call `redeem()` multiple times during this stage
- Each call processes all eligible tokens owned by the user at that moment
- Once a token is redeemed, it is transferred to the contract and cannot be redeemed again
- Users who don't redeem during this stage cannot claim in PostRedemption
- **Additional ETH Deposits**: The owner or any other party can send additional ETH to the contract at any time during the Redemption stage. These deposits do not change the `redemptionPerHash` rate for Stage 2 redemptions (which is fixed at stage start), but they increase the total pool that will be available for PostRedemption distribution.

#### Stage 3: PostRedemption

**What Happens:**
- After at least 180 days have passed since the Redemption stage was set, the owner can call `setPostRedemptionStage()`
- The contract recalculates `redemptionPerHash = contractBalance / totalNumberRedeemed`
  - This redistributes any remaining ETH (from tokens not redeemed) to users who did redeem
  - If no tokens were redeemed, this will revert (division by zero)
- Users who redeemed in Stage 2 can claim additional ETH

**User Actions:**
1. Users who redeemed tokens in Stage 2 can call `redeem()` again
2. The contract will:
   - Retrieve `amountRedeemed[user]` (the count of tokens they redeemed in Stage 2)
   - Calculate payout: `amountRedeemed[user] × redemptionPerHash`
   - Transfer the ETH to the user
   - Reset `amountRedeemed[user]` to 0 (preventing double claims)

**Example:**
- 400 tokens were redeemed in Stage 2 (out of 579 eligible)
- Contract has 20 ETH remaining
- `redemptionPerHash = 20 ETH / 400 = 0.05 ETH per token`
- User who redeemed 5 tokens in Stage 2 receives: `5 × 0.05 ETH = 0.25 ETH`

**Important Notes:**
- Only users who redeemed in Stage 2 can claim in PostRedemption
- Users who didn't redeem in Stage 2 cannot claim, even if they hold eligible tokens
- Each user can only claim once in PostRedemption stage