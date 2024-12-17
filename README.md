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

## Security & Audits
Here are the audits we completed with Halborn:
1. [Protocol-wide audit](https://docs.google.com/viewerng/viewer?url=https://files.gitbook.com/v0/b/gitbook-x-prod.appspot.com/o/spaces%252FuV2CWL0AZicnZxx3SgUP%252Fuploads%252FDMjHMORByqrQnWTCL5Rs%252FFortunaFi_Reservoir_Smart_Contract_Security_Audit_Report_Halborn_Final.pdf?alt%3Dmedia%26token%3Dbb69023c-f54b-45c7-a44b-5e151002777e)
2. [Morpho lending market audit](https://drive.google.com/file/d/1JaIcwJRn169PGhnF_0nRd6E6bYvxmlNv/view)
3. [Cross-chain bridging audit](https://files.gitbook.com/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FuV2CWL0AZicnZxx3SgUP%2Fuploads%2FLNmg84HNDNlNKagf9jLo%2FReservoir%20Protocol%20-%20lz-bridge%20_%20SSC.pdf?alt=media&token=168abe3d-0650-454c-bfa5-592b7c08ad83)

We accept security bug reports at security@reservoir.xyz
