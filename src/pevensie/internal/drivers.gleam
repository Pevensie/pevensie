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

pub type AuthDriver {
  PostgresAuthDriver(config: pgo.Config, conn: Option(pgo.Connection))
}

// TODO: Better error type
pub fn connect_auth_driver(driver: AuthDriver) -> Result(AuthDriver, Nil) {
  case driver {
    PostgresAuthDriver(config, None) -> {
      let conn = pgo.connect(config)

      Ok(PostgresAuthDriver(config, Some(conn)))
    }
    _ -> Error(Nil)
  }
}

pub fn disconnect_auth_driver(driver: AuthDriver) -> Result(AuthDriver, Nil) {
  case driver {
    PostgresAuthDriver(config, Some(conn)) -> {
      let _ = pgo.disconnect(conn)
      Ok(PostgresAuthDriver(config, None))
    }
    _ -> Error(Nil)
  }
}
