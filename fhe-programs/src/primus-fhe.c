typedef unsigned long long uint64_t;

// Update the tip amount and spent amount based on the current amount of
// deposited tokens. If the tipper has not deposited enough tokens, the tip
// amount is set to zero and the spent value is unchanged (but the ciphertext is
// new).
[[clang::fhe_program]]
void updateTip(uint64_t zero,
               [[clang::encrypted]] uint64_t amount,
               uint64_t balance,
               [[clang::encrypted]] uint64_t spent,
               [[clang::encrypted]] uint64_t *updated_amount,
               [[clang::encrypted]] uint64_t *updated_spent) {
  // Check for overflow
  *updated_amount = (amount + spent) < spent ? zero : amount;

  // Check, given our current balance and amount spent from that balance, that
  // we can spend the amount we want. Otherwise set the updated amount to zero.
  *updated_amount = (amount + spent) > balance ? zero : *updated_amount;
  *updated_spent = spent + *updated_amount;
}

// Add the given amount to the balance, checking for overflow. If the amount to
// add is too large, the updated balance is unchanged.
[[clang::fhe_program]]
void addToBalance(uint64_t zero,
                  [[clang::encrypted]] uint64_t amount,
                  [[clang::encrypted]] uint64_t balance,
                  [[clang::encrypted]] uint64_t *updated_balance) {
  // Check for overflow
  *updated_balance = (amount + balance) < balance ? balance : amount + balance;
}

// Withdraw from the balance only if the amount is available. Otherwise withdraw
// zero and the balance is unchanged.
[[clang::fhe_program]]
void withdraw(uint64_t zero,
              uint64_t amount,
              [[clang::encrypted]] uint64_t balance,
              [[clang::encrypted]] uint64_t *updated_amount,
              [[clang::encrypted]] uint64_t *updated_balance) {

  // Check for having the amount necessary to withdraw
  *updated_amount = (amount > balance) ? zero : amount;
  *updated_balance = balance - *updated_amount;
}
