# Script to clear the ETS idempotency cache
# Run with: mix run clear_cache.exs

alias IsupayxWeb.Plugs.IdempotencyCheck

case IdempotencyCheck.clear_cache() do
  {:ok, :cleared} ->
    IO.puts("✓ Cleared all entries from :idempotency_cache")
  {:error, :table_not_found} ->
    IO.puts("Cache table doesn't exist yet - nothing to clear")
end

# Also clear the transaction with idempotency_key "idem_001"
alias Isupayx.Repo
alias Isupayx.Transactions.Transaction

case Repo.get_by(Transaction, idempotency_key: "idem_001") do
  nil ->
    IO.puts("No transaction with idempotency_key 'idem_001' found")
  transaction ->
    Repo.delete(transaction)
    IO.puts("✓ Deleted transaction with idempotency_key 'idem_001'")
end

IO.puts("\n✓ Ready to test TC1 from scratch!")
