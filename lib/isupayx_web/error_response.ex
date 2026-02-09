defmodule IsupayxWeb.ErrorResponse do
  @moduledoc """
  Standardized error response format for the iSupayX API.
  
  All validation errors follow this structure:
  {
    "error": {
      "code": "ERROR_CODE",
      "layer": "validation_layer",
      "message": "Human readable message",
      "details": {...}  // Optional field-specific details
    }
  }
  """

  @doc """
  Creates a standardized error response map.
  
  ## Parameters
  - layer: The validation layer that failed (schema, entity, business_rule, compliance, risk)
  - code: Error code (e.g., SCHEMA_MISSING_FIELD)
  - message: Human-readable error message
  - details: Optional map with field-specific error details
  """
  def build(layer, code, message, details \\ %{}) do
    error = %{
      code: code,
      layer: layer,
      message: message
    }
    
    error = if map_size(details) > 0 do
      Map.put(error, :details, details)
    else
      error
    end
    
    %{error: error}
  end

  @doc """
  Converts error response to JSON with appropriate HTTP status code.
  Returns {status_code, json_body}
  """
  def to_response(layer, code, message, details \\ %{}) do
    status = http_status_for_layer(layer)
    body = build(layer, code, message, details)
    {status, body}
  end

  # Maps validation layers to HTTP status codes
  defp http_status_for_layer("schema"), do: 400
  defp http_status_for_layer("entity"), do: 403
  defp http_status_for_layer("business_rule"), do: 422
  defp http_status_for_layer("compliance"), do: 201  # Compliance warnings don't fail the request
  defp http_status_for_layer("risk"), do: 429
  defp http_status_for_layer("auth"), do: 401
  defp http_status_for_layer("idempotency"), do: 409
  defp http_status_for_layer(_), do: 500
end
