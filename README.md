[![Build](https://github.com/fortunafi/reservoir/actions/workflows/test.yml/badge.svg?branch=wissam/add-code-coverage)](https://github.com/fortunafi/reservoir/actions/workflows/test.yml)
[![Coverage](https://reservoir-code-coverage-public.s3.us-west-2.amazonaws.com/master/coverage.svg?no-cache)](https://github.com/fortunafi/reservoir/actions/workflows/coverage.yml)

This repository contains the full suite of smart contracts that define the Reservoir protocol. User's are able to
purchase the native stablecoin *rUSD* and exchange it for a fixed term or variable rate yield bearing tokens *trUSD* and
*srUSD*. The liabilities of the protocol are backed by a mix of real world assets (RWA)s and onchain yield bearing assets in lending protocols and AMMs.

The assets where capital is allocated is fully configurable through governance, and
solvency in the protocol is controlled by ratios set through governance that constrain leverage in the system.

## Getting Started

```bash
    $ forge install

    $ forge test
```

Scripts used for deployment can be found under `bin/`.

## Audits

