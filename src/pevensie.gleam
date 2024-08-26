import pevensie/internal/pevensie

/// Create a new Pevensie instance.
pub const new = pevensie.new

/// Set up a Pevensie auth connection.
pub const connect_auth = pevensie.connect_auth

/// Disconnect a Pevensie auth driver.
pub const disconnect_auth = pevensie.disconnect_auth

/// Configure a Pevensie instance with auth.
pub const with_auth = pevensie.with_auth

/// Set up a Pevensie cache connection.
pub const connect_cache = pevensie.connect_cache

/// Disconnect a Pevensie cache driver.
pub const disconnect_cache = pevensie.disconnect_cache

/// Configure a Pevensie instance with cache.
pub const with_cache = pevensie.with_cache
