# Imposer Project Configuration

This file is the global configuration for imposer.  You can add project-specific commands, PHP tweaks, option settings, or anything else that's valid in an [imposer](https://github.com/dirtsimple/imposer) state file.

By default, all this file does is load the [`Mantle` state](imposer/Mantle.state.md), and any states listed in `$MANTLE_STATES`:


```shell
# Load the mantle state and any states specified by the environment
require Mantle ${MANTLE_STATES-}
```

