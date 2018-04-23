# Imposer Project Configuration

This file is the global configuration for imposer.  You can add project-specific commands, PHP tweaks, option settings, or anything else that's valid in an imposer state file.  By default, all this file does is load the `mantle` state (found in `imposer/mantle.state.md`), and the states listed in `$MANTLE_STATES`.


```shell
# Load the mantle state and any states specified by the environment
require mantle ${MANTLE_STATES-}
```

