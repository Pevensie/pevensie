import gleam/dynamic.{type Decoder}
import pevensie/internal/drivers.{type AuthDriver}

pub type AuthConfig(user_metadata, connected) {
  AuthConfig(driver: AuthDriver, user_metadata_decoder: Decoder(user_metadata))
  AuthDisabled
}
