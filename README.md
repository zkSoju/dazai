# Mira Smart Contracts

## Overview

- [ ] Merkle Tree whitelists
- [ ] Dutch auction
- [ ] Signed transactions
- [ ] Gas optimizations

  - [ ] Custom Errors
  - [ ] Bulk Minting

# Additional Notes

- Usage of Solmate strips out `currentSupply()` and incorporates gas optimizations like unchecked counters because it's impossible to underflow or overflow due to prior checks.

- Usage of ERC721 incorporates batch minting optimizations that make initial singular mint slightly more costly, but subsequent significantly less compared to OZ.

## Testing Results

```
ERC721ATest:testIsolatedMultiMint() (gas: 152114)
ERC721ATest:testIsolatedSingleMint() (gas: 132123)

SolmateTest:testIsolatedMultiMint() (gas: 331775)
SolmateTest:testIsolatedSingleMint() (gas: 105369)
```

# Acknowledgements

- [erc721a](https://github.com/chiru-labs/ERC721A)
- [foundry](https://github.com/gakonst/foundry)
- [solmate](https://github.com/Rari-Capital/solmate)
- [forge-std](https://github.com/brockelmore/forge-std)
- [clones-with-immutable-args](https://github.com/wighawag/clones-with-immutable-args)
- [foundry-toolchain](https://github.com/onbjerg/foundry-toolchain) by [onbjerg](https://github.com/onbjerg)
- [forge-template](https://github.com/abigger87/foundry-starter) by [abigger87](https://github.com/abigger87)
- [Georgios Konstantopoulos](https://github.com/gakonst) for [forge-template](https://github.com/gakonst/forge-template) resource
