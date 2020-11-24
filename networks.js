const {projectId, mnemonic} = require('./secrets.json');
const HDWalletProvider = require('@truffle/hdwallet-provider');
module.exports = {
    networks: {
        development: {
            protocol: 'http',
            host: 'localhost',
            port: 8545,
            gas: 20000000,
            gasPrice: 5e9,
            networkId: '*',
        },
        rinkeby: {
            provider: () => new HDWalletProvider(
                mnemonic, `https://rinkeby.infura.io/v3/${projectId}`
            ),
            networkId: 4,
            gasPrice: 10e9
        },
        kovan: {
            provider: () => new HDWalletProvider(
                mnemonic, `https://kovan.infura.io/v3/${projectId}`
            ),
            networkId: 42,
            gasPrice: 20e9
        },
        mainnet: {
            provider: () => new HDWalletProvider(
                mnemonic, `https://mainnet.infura.io/v3/${projectId}`
            ),
            networkId: 1,
            gasPrice: 40e9
        }
    },
};
