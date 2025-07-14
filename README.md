# 🎵 Beatland festival

- Starts: July 17, 2025 Noon UTC
- Ends: July 24, 2025 Noon UTC

- nSLOC: 234
- Complexity Score: 252

[//]: # (contest-details-open)

## About the Project

A festival NFT ecosystem on Ethereum where users purchase tiered passes (ERC1155), attend virtual(or not) performances to earn BEAT tokens (ERC20), and redeem unique memorabilia NFTs (integrated in the same ERC1155 contract) using BEAT tokens.

## Actors

Owner: The owner and deployer of contracts, sets the Organizer address, collects the festival proceeds.

Organizer: Configures performances and memorabilia.

Attendee: Customer that buys a pass and attends performances. They use rewards received for attending performances to buy memorabilia.


[//]: # (contest-details-close)

[//]: # (scope-open)

## Scope (contracts)

```js
src/
├── BeatToken.sol
├── FestivalPass.sol
├── interfaces
│   ├── IFestivalPass.sol

```

## Compatibilities

```
Compatibilities:
  Blockchains:
      - Ethereum
  Tokens:
      - Native ETH
      - BeatToken is ERC20
      - Festival passes and memorabilia are built within the same ERC1155.
```

[//]: # (scope-close)

[//]: # (getting-started-open)

## Setup

Do the following to build the project.

```bash
foundryup

export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

git clone XXXXXXRepoGoesHere

cd folderNameXXXX

forge install foundry-rs/forge-std --no-commit

forge install OpenZeppelin/openzeppelin-contracts --no-commit

forge build

forge test
```

Alternatively you could use `make` after cloning the repo and changing the directory.

[//]: # (getting-started-close)

[//]: # (known-issues-open)

## Known Issues

- Owner and Organizer are trusted.
- Some checks were left out for gas efficiency.
- The uri address we used inside the ERC1155 constructor is provisional, we will deal with that closer to live deployment.
