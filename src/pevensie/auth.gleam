import gleam/dynamic.{type Decoder}
import gleam/option.{Some}
import gleam/result
import pevensie/internal/auth
import pevensie/internal/drivers.{
  type AuthDriver, type Connected, PostgresAuthDriver,
}
import pevensie/internal/pevensie.{type Pevensie}
import pevensie/internal/postgres
import pevensie/internal/user.{type User as InternalUser}

pub type User(user_metadata) =
  InternalUser(user_metadata)

pub type AuthConfig(user_metadata, connected) =
  auth.AuthConfig(user_metadata, connected)

pub fn new_auth_config(
  driver driver: AuthDriver(status),
  user_metadata_decoder user_metadata_decoder: Decoder(user_metadata),
) -> AuthConfig(user_metadata, status) {
  auth.AuthConfig(driver, user_metadata_decoder)
}

pub fn get_user_by_id(
  pevensie: Pevensie(user_metadata, Connected),
  id: String,
) -> Result(User(user_metadata), Nil) {
  case pevensie.auth_config.driver {
    PostgresAuthDriver(conn: Some(conn), ..) -> {
      postgres.get_user_by_id(
        conn,
        id,
        pevensie.auth_config.user_metadata_decoder,
      )
      |> result.map_error(fn(_) { Nil })
    }
    _ -> Error(Nil)
  }
}
