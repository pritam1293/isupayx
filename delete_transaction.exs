# Delete transaction with specific idempotency key
# Run with: mix run delete_transaction.exs idem_001

alias Isupayx.Repo

idempotency_key = System.argv() |> List.first() || "idem_001"

{:ok, result} = Repo.query(
  "DELETE FROM transactions WHERE idempotency_key = ?",
  [idempotency_key]
)

case result.num_rows do
  0 ->
    IO.puts("❌ No transaction found with idempotency_key '#{idempotency_key}'")
  n ->
    IO.puts("✓ Deleted #{n} transaction(s) with idempotency_key '#{idempotency_key}'")
end
