/**
 * @type import('hardhat/config').HardhatUserConfig
 */

const ROPSTEN_PRIVATE_KEY =
  "cd9e715276ca67c9543c6f6aed6ea815f0b4d72a0eeb42823139d2904cf0f211";
const INFURA_PRIVATE_KEY = "0a7bead9f80645659e59508d1de7bd88";

module.exports = {
  defaultNetwork: "ropsten",
  networks: {
    hardhat: {},
    ropsten: {
      url: `https://ropsten.infura.io/v3/${INFURA_PRIVATE_KEY}`,
      accounts: [ROPSTEN_PRIVATE_KEY],
    },
  },
  solidity: "0.7.3",
  settings: {
    optimizer: {
      enabled: true,
      runs: 200,
    },
  },
  paths: {
    sources: "./src",
    tests: "./src/test",
  },
};
