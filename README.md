# Acme
[![Build Status](https://semaphoreci.com/api/v1/sikanhe/acme/branches/master/badge.svg)](https://semaphoreci.com/sikanhe/acme)
## Installation

Add `acme` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:acme, "~> 0.1.0"}]
end
```

## How to connect to an Acme server

All client request are called with a connection. I chose to do it this
way (over something like hard coded config) so you have the flexability
to run multiple connections to many Acme servers at the same time or fetch
certificates for different accounts.

To connect to an Acme server, you want use the &Acme.Client.start_link/1 function
that takes these options:

  * `server_url` - The Acme server url
  * `private_key` - A private_key either in PEM format or as a JWK map, this is
  required unless you use the `private_key_file` option
  * `private_key_file` - Instead of a private key map/pem value, you can also pass
  a private key file path

```elixir
{:ok, conn} = Acme.Client.start_link([
  server: "https://acme-v01.api.letsencrypt.org/directory",
  private_key_file: "path/to/key.pem"
])
```

## Examples

### Staring a connection
```elixir
Acme.Client.start_link(server: ..., private_key: ...)
#=> {:ok, conn}
```

We are going to reuse this connection for all examples below

### Register an account
```elixir
Acme.register("mailto:acme@example.com") |> Acme.request(conn)
#=> {:ok, %Registration{...}}
# Agree to terms
Acme.agree_terms(registration) |> Acme.request(conn)
```

### Get new authorization for domain
```elixir
Acme.authorize("yourdomain.com") |> Acme.request(conn)
#=> {:ok, %Authorization{
  status: "pending",
  challanges: [
    %Acme.Challenge{
      type: "http-01",
      token "..."
    }
  ]
}}
```

### Respond to a challenge
```elixir
challenge = %Acme.Challenge{type: "http-01", token: ...}
Acme.respond_challenge(challenge) |> Acme.request(conn)
#=> {:ok, %Challenge{status: "pending", ...}}
```

### Request a certificate
Generate a CSR, we provide OpenSSL helpers to help you with this
in Acme.OpenSSL

```elixir
# Certificate subject informations (only common_name is required)
subject = %{
  common_name: "example.acme.com",
  organization_name: "Acme INC.",
  organizational_unit: "HR",
  locality_name: "New York",
  state_or_province: "NY",
  country_name: "United States"
}

# Generate a CSR in DER format
{:ok, csr} = Acme.OpenSSL.generate_csr("/path/to/your/private_key.pem", subject)

# Request a certificate and get back its URL
Acme.new_certificate(csr) |> Acme.request(conn)
#=> {:ok, "https://example.com/acme/cert/asdf"}

# Fetch the certificate using the URL
Acme.get_certificate("https://example.com/acme/cert/asdf")
|> Acme.request(conn)
#=> {:ok, <<DER-encoded certificate>>}
```

### Revoke a certificate
You can revoke a certificate by passing the certificate in DER format
and specify a reason code.
You can see all possible reason codes at:
https://tools.ietf.org/html/rfc5280#section-5.3.1

```elixir
Acme.revoke_certificate(<<DER-encoded certificate>>, 0)
#=> :ok
```

# License
The MIT License (MIT)

Copyright (c) 2017-present, Sikan He

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.