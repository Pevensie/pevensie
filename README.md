# Pevensie

[![Package Version](https://img.shields.io/hexpm/v/pevensie)](https://hex.pm/packages/pevensie)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/pevensie/)

The backend application framework for Gleam!

## Getting Started

```sh
gleam add pevensie
```

Pevensie uses a driver-based architecture, so most modules in the framework will
require you to provide a driver for them to use. The drivers provided with
Pevensie are:

- [Postgres](https://github.com/Pevensie/pevensie_postgres) - A driver for PostgreSQL
- Redis - A driver for Redis (coming soon)
- ETS - A driver for ETS, Erlang's in-memory key-value store (coming soon)

The hope is that other first- and third-party drivers will be available in the
future.

> Note: database-based drivers will require migrations to be run before using
> them. See the documentation for your chosen driver for more information.

## Example

The below example uses Pevensie Auth to create a user, create a session for that
user, and create a signed cookie that can be used to authenticate future requests.

```gleam
import gleam/dynamic/decode.{type DecodeError}
import gleam/json
import gleam/option.{None, Some}
import pevensie/auth
import pevensie/postgres

type UserMetadata {
  UserMetadata(name: String, age: Int)
}

fn user_metadata_encoder(user_metadata: UserMetadata) -> json.Json {
  json.object([
    #("name", json.string(user_metadata.name)),
    #("age", json.int(user_metadata.age)),
  ])
}

fn user_metadata_decoder() -> Result(UserMetadata, List(DecodeError)) {
  use name <- decode.field("name", decode.string)
  use age <- decode.field("age", decode.int)
  decode.success(UserMetadata(name: name, age: age))
}

pub fn main() {
  let config = postgres.default_config()
  let driver = postgres.new_auth_driver(config)
  let pevensie_auth = auth.new(
    driver,
    user_metadata_decoder,
    user_metadata_encoder,
    "super secret cookie signing key",
  )

  // Set up the Postgres connection pool
  let assert Ok(pevensie_auth) = auth.connect(pevensie_auth)

  // Create a user
  let assert Ok(user) =
    pevensie_auth
    |> auth.create_user_with_email(
      "lucy@pevensie.dev",
      "password",
      UserMetadata(name: "Lucy Pevensie", age: 8),
    )

  // Create a session for the user
  let assert Ok(session) =
    pevensie_auth
    |> auth.create_session(
      user.id,
      None,
      None,
      Some(24 * 60 * 60),
    )

  // Create a signed cookie for the session
  let assert Ok(session_cookie) =
    pevensie_auth
    |> auth.create_session_cookie(session)
}
```

Further documentation can be found at <https://hexdocs.pm/pevensie>.

## Feedback and feature requests

If you have any feedback or feature requests, please open an issue on the
[Pevensie GitHub repository](https://github.com/Pevensie/pevensie).

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```

### V1 checklist

> [!NOTE]
> This section will be replaced with a proper GitHub project board shortly.

- [ ] Add more decoders for JSON representation of provided types
- [ ] Decide on a stable architecture
- [ ] Add more drivers (Redis, ETS)
- [ ] Write unit and integration tests
- [ ] Add Pevensie Jobs for async/background tasks
- [ ] Email confirmation tokens
- [ ] Email change tokens
