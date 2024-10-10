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

- [Postgres](/pevensie/drivers/postgres.html) - A driver for PostgreSQL
- [Redis](/pevensie/drivers/redis.html) - A driver for Redis (coming soon)
- [ETS](/pevensie/drivers/ets.html) - A driver for ETS, Erlang's in-memory key-value store (coming soon)

The hope is that other first- and third-party drivers will be available in the
future.

> Note: database-based drivers will require migrations to be run before using
> them. See the documentation for your chosen driver for more information.

## Example

The below example uses Pevensie Auth to create a user, create a session for that
user, and create a signed cookie that can be used to authenticate future requests.

```gleam
import gleam/dynamic.{type DecodeError}
import gleam/json
import gleam/option.{None, Some}
import pevensie/auth
import pevensie/drivers/postgres

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
  decode.into({
    use name <- decode.parameter
    use age <- decode.parameter
    Ok(UserMetadata(name: name, age: age))
  })
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

## Why v0?

The Gleam community generally holds the (correct) opinion that libraries should not be
released until they're ready. Thus, version numbers pre-v1 generally don't exist.

However, Pevensie is starting with v0 versions for a couple of reasons, which can be
seen below.

> [!CAUTION]
> This is a beta version of Pevensie, and is not yet ready for production use.
> Consider nothing to be stable, including database migrations. They, or the
> format they use, may change at any time before v1.

While the project is in v0, patch versions will be used for bug fixes, and minor
versions will be used for new features, which may be backwards-incompatible.

### Security

I've never written an authentication library before, and I'm not a security expert.
There's a non-zero chance that I've made a mistake somewhere, and there's a security
vulnerability somewhere in Pevensie Auth.

By releasing a v0 version of Pevensie, I give the community a chance to find and flag
any security issues before they're released into the wild under the guise of a
'production-ready' framework.

### The API

While it's currently fairly small, Pevensie's architecture is somewhat complex, aiming
to be opinionated where it's needed, but still flexible enough to allow users to choose
the majority of their tech stack (hence the driver-based design).

I can't guarantee that this approach is the best, and the best way to validate that is
to see how the community use the framework. Having a v0 means that both the
public-facing API and the driver API can change quickly until some sort of stable
configuration is reached.

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
