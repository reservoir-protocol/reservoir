# Reservoir Protocol

Set of smart contracts that act as a bank issuing liabilities in the form of tokens: *rUSD*, *srUSD*, and *trUSD*, which will be backed by assets and restricted in their supply by the configured solvency ratios.

## Introduction

This repository contains the full suite of smart contracts that define the Reservoir protocol. User's are able to purchase the native stablecoin *rUSD* and exchange it for fixed term or variable rate yield bearing tokens *trUSD* and *srUSD*. The liabilities of the protocol are backed by a mix of Real World Assets (RWA) and onchain yield bearing assets in lending protocols and AMMs.

The assets where capital is allocated is fully configurable through governance, and
solvency in the protocol is controlled by ratios set through governance that constrain leverage in the system.

## Flow of Funds

The sequence of actions between users and the fund administrator (governance):

    User deposits *USDC* or redeems *rUSD*
    Fund administrator (governance) moves capital between the peg stability module and any of the asset adapters add to the credit enforcer
    Fund administrator (governance) leaves some capital in the peg stability module for any potential upcoming redemptions
    The price of the asset adapters change automatically and reflect a new asset value to the protocol

## Operations

Governance is able to transfer USDC from the PSM to the different modules that generate yield for the protocol. USDC is moved into a variety of DeFi ecosystems and used for investment in Real World Assets (RWAs)

### Deposit

Users deposit their USDC into the peg stability module and receive *rUSD*, from there they are able to use their *rUSD* in whatever way they choose, getting liquid and term yield with *srUSD* and *trUSD* or simply using it across the DeFi ecosystem.

### Redemptions

For redemptions, a user is able to receive back USDC for their *rUSD* up to the amount available in the PSM which is restricted to some percentage of the total *rUSD* outstanding.

## Setup

```bash
    $ curl -L https://foundry.paradigm.xyz | bash
```

```bash
    $ forge install

    $ forge test
```

## Development

Foundry tests cover all the possible cases that can occur while interacting with functions, or in general flow. To run Foundry tests, use the following cmd:

```bash
    $ forge test
```

## Deployment

### Local

```
anvil
```

## Ethereum

Scripts used for deployment can be found under `bin/`.

## Audits
