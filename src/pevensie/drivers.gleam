pub type Connected

pub type Disconnected

pub type Disabled

/// A function that connects the driver. This may
/// set up any connections or perform any other setup
/// required to make the driver ready to use.
pub type ConnectFunction(driver) =
  fn(driver) -> Result(driver, Nil)

/// A function that disconnects the driver. This may
/// tear down any connections or perform any other cleanup
/// required once the driver is no longer needed.
pub type DisconnectFunction(driver) =
  fn(driver) -> Result(driver, Nil)
