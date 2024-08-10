import gleam/option.{type Option, None, Some}
import gleam/pgo

pub opaque type Connected {
  Connected
}

pub opaque type Disconnected {
  Disconnected
}

pub opaque type Disabled {
  Disabled
}

pub type AuthDriver(status) {
  PostgresAuthDriver(config: pgo.Config, conn: Option(pgo.Connection))
  NullAuthDriver
}

pub fn disabled() -> AuthDriver(Disabled) {
  NullAuthDriver
}

// TODO: Better error type
pub fn connect_auth_driver(
  driver: AuthDriver(Disconnected),
) -> Result(AuthDriver(Connected), Nil) {
  case driver {
    PostgresAuthDriver(config, None) -> {
      let conn = pgo.connect(config)

      Ok(PostgresAuthDriver(config, Some(conn)))
    }
    _ -> Error(Nil)
  }
}

pub fn disconnect_auth_driver(
  driver: AuthDriver(Connected),
) -> Result(AuthDriver(Disconnected), Nil) {
  case driver {
    PostgresAuthDriver(config, Some(conn)) -> {
      let _ = pgo.disconnect(conn)
      Ok(PostgresAuthDriver(config, None))
    }
    _ -> Error(Nil)
  }
}
