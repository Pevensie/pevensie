import gleam/result
import pevensie/internal/auth.{type AuthConfig, AuthConfig}
import pevensie/internal/drivers.{
  type Connected, type Disconnected, connect_auth_driver, disconnect_auth_driver,
}

pub type Pevensie(user_metadata, auth_status) {
  Pevensie(auth_config: AuthConfig(user_metadata, auth_status))
}

pub fn init(
  auth auth_config: AuthConfig(user_metadata, Disconnected),
) -> Pevensie(user_metadata, Disconnected) {
  Pevensie(auth_config)
}

pub fn connect_auth(
  pevensie: Pevensie(user_metadata, Disconnected),
) -> Result(Pevensie(user_metadata, Connected), Nil) {
  connect_auth_driver(pevensie.auth_config.driver)
  |> result.map(fn(auth_driver) {
    Pevensie(AuthConfig(
      user_metadata_decoder: pevensie.auth_config.user_metadata_decoder,
      driver: auth_driver,
    ))
  })
}

pub fn disconnect_auth(
  pevensie: Pevensie(user_metadata, Connected),
) -> Result(Pevensie(user_metadata, Disconnected), Nil) {
  disconnect_auth_driver(pevensie.auth_config.driver)
  |> result.map(fn(auth_driver) {
    Pevensie(AuthConfig(
      user_metadata_decoder: pevensie.auth_config.user_metadata_decoder,
      driver: auth_driver,
    ))
  })
}
