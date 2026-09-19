# SPDX-License-Identifier: MPL-2.0
# Run: elixir test/interop/capability_gateway.exs /path/to/http-capability-gateway
# This tests the REAL upstream policy pipeline, not its HTTP proxy/listener.
Mix.install([{:yaml_elixir, "2.11.0"}, {:jason, "1.4.4"}])
[root] = System.argv()
for name <- ["policy_loader", "policy_validator", "policy_compiler"] do
  Code.require_file(Path.join([root, "lib", "http_capability_gateway", name <> ".ex"]))
end
ExUnit.start()

defmodule MaridCapabilityInteropTest do
  use ExUnit.Case, async: false
  alias HttpCapabilityGateway.{PolicyLoader, PolicyValidator, PolicyCompiler}

  test "generated YAML loads, validates, compiles, and enforces non-global verbs" do
    {:ok, policy} = PolicyLoader.load_from_file("fixtures/capability/policy.yaml")
    assert :ok == PolicyValidator.validate(policy)
    {:ok, table} = PolicyCompiler.compile(policy)
    on_exit(fn ->
      Application.delete_env(:http_capability_gateway, :policy_table)
      Application.delete_env(:http_capability_gateway, :policy_regex_table)
    end)
    assert {:ok, _} = PolicyCompiler.lookup(table, "/api/entities", :POST)
    assert {:ok, _} = PolicyCompiler.lookup(table, "/api/entities/42", :GET)
    assert {:ok, rule} = PolicyCompiler.lookup(table, "/api/export.v1", :POST)
    assert rule.capability == "entities:export"
    assert rule.exposure == "public"
    for path <- ["/api/exportXv1", "/api/export.v1/more", "/api/export.v1\n", "/unknown"] do
      assert {:error, :no_match} = PolicyCompiler.lookup(table, path, :POST)
    end
    assert {:error, :no_match} = PolicyCompiler.lookup(table, "/api/entities", :DELETE)
    assert {:error, :no_match} = PolicyCompiler.lookup(table, "/api/entities", :HEAD)
    assert {:error, :no_match} = PolicyCompiler.lookup(table, "/api/entities", :OPTIONS)

    # Global fallback still applies on UNKNOWN paths when explicitly configured.
    assert {:ok, global} = PolicyCompiler.lookup(table, "/unknown", :GET)
    assert global.exposure == "public"
    assert {:error, :no_match} = PolicyCompiler.lookup(table, "/api/export.v1", :GET)
    {:ok, strict} = PolicyLoader.load_from_file("fixtures/capability/policy-strict.yaml")
    assert :ok = PolicyValidator.validate(strict)
    {:ok, strict_table} = PolicyCompiler.compile(strict)
    assert {:ok, _} = PolicyCompiler.lookup(strict_table, "/api/entities", :POST)
    assert {:error, :no_match} = PolicyCompiler.lookup(strict_table, "/unknown", :GET)
    assert {:error, :no_match} = PolicyCompiler.lookup(strict_table, "/api/export.v1", :GET)
  end
end
