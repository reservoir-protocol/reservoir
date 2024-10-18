This repository contains the full suite of smart contracts that define the Reservoir protocol. User's are able to
purchase the native stablecoin _rUSD_ and exchange it for a fixed term or variable rate yield bearing tokens _trUSD_ and
_srUSD_. The liabilities of the protocol are backed by a mix of real world assets (RWA)s and onchain yield bearing assets in lending protocols and AMMs.

The assets where capital is allocated is fully configurable through governance, and
solvency in the protocol is controlled by ratios set through governance that constrain leverage in the system.

## Getting Started

```bash
    $ forge install

    $ forge test
```

Scripts used for deployment can be found under `bin/`.

## Audits
