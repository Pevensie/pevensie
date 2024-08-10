import gleam/dynamic.{type Decoder}
import gleam/option.{Some}
import gleam/result
import pevensie/internal/auth
import pevensie/internal/drivers.{
  type AuthDriver, type Connected, type Disabled, type Disconnected,
  PostgresAuthDriver,
}
import pevensie/internal/pevensie.{type Pevensie}
import pevensie/internal/postgres
import pevensie/internal/user.{type User as InternalUser}

pub type User(user_metadata) =
  InternalUser(user_metadata)

pub type AuthConfig(user_metadata, connected) =
  auth.AuthConfig(user_metadata, connected)

pub fn new_auth_config(
  driver driver: AuthDriver,
  user_metadata_decoder user_metadata_decoder: Decoder(user_metadata),
) -> AuthConfig(user_metadata, Disconnected) {
  auth.AuthConfig(driver, user_metadata_decoder)
}

pub fn disabled() -> AuthConfig(user_metadata, Disabled) {
  auth.AuthDisabled
}

pub fn get_user_by_id(
  pevensie: Pevensie(user_metadata, Connected),
  id: String,
) -> Result(User(user_metadata), Nil) {
  let assert auth.AuthConfig(driver, user_metadata_decoder) =
    pevensie.auth_config

  case driver {
    PostgresAuthDriver(conn: Some(conn), ..) -> {
      postgres.get_user_by_id(conn, id, user_metadata_decoder)
      |> result.map_error(fn(_) { Nil })
    }
    _ -> Error(Nil)
  }
}
