defmodule IsupayxWeb.Plugs.AuthenticateMerchant do
  @moduledoc """
  Plug to authenticate merchants via X-Api-Key header.
  
  Extracts API key from header and validates merchant.
  If valid, assigns merchant to conn. If invalid, halts with 401.
  """

  import Plug.Conn
  alias Isupayx.Validation.EntityValidator
  alias IsupayxWeb.ErrorResponse

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "x-api-key") do
      [] ->
        # TC10: Missing API key
        send_error(conn, "auth", "AUTH_MISSING_API_KEY", "X-Api-Key header is required")
      
      [api_key | _] ->
        case EntityValidator.validate(api_key) do
          {:ok, merchant} ->
            # Success: assign merchant to conn for use in controller
            assign(conn, :current_merchant, merchant)
          
          {:error, {layer, code, message, details}} ->
            # Entity validation failed (merchant not found, inactive, or KYC invalid)
            send_error(conn, layer, code, message, details)
        end
    end
  end

  defp send_error(conn, layer, code, message, details \\ %{}) do
    {status, body} = ErrorResponse.to_response(layer, code, message, details)
    
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(body))
    |> halt()
  end
end
