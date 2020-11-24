const {accounts, contract, web3} = require('@openzeppelin/test-environment');
const {
  BN,          // Big Number support
  constants,    // Common constants, like the zero address and largest integers
  expectEvent,  // Assertions for emitted events
  expectRevert, // Assertions for transactions that should fail
  time,
} = require('@openzeppelin/test-helpers');

const {
  etherExp,
  etherDouble,
  etherMantissa,
} = require('./Utils/Ethereum');

const {expect} = require('chai');
const ethers = require('ethers');

const SimplePriceOracle = contract.fromArtifact('SimplePriceOracle'); // Loads a compiled contract
const MockErc20 = contract.fromArtifact('MockErc20');

describe('SimplePriceOracle', function () {
    const [alice, bob, carol, minter] = accounts;
    const eth_address = '0x0000000000000000000000000000000000000000'
    // const opts = {kind: "hello", comptrollerOpts: {kind: "v1-no-proxy"}, supportMarket: true};

    beforeEach(async () => {
    	this.value = new BN(18);
      this.priceOracle = await SimplePriceOracle.new();
      this.priceOracle.initialize();
      this.pToken = await MockErc20.new('pToken', 'PT', '10000000000', {from: minter});
      this.pETH = await MockErc20.new('pETH', 'pETH', '10000000000', {from: minter});
    });

    it('should only allow owner to set price or uderlyingPrice', async () => {
        await expectRevert(this.priceOracle.setUnderlyingPrice(eth_address, etherExp(460), {from :alice}),"Ownable: caller is not the owner")
        await expectRevert(this.priceOracle.setPrice(eth_address, etherExp(460), {from :alice}),"Ownable: caller is not the owner")
    });

    it('get setting prices', async () => {
        // await this.priceOracle.setUnderlyingPrice(this.pETH.address, etherExp(460));
        await this.priceOracle.setPrice(eth_address, etherExp(460));
        const eth_getprice = await this.priceOracle.getPrice(eth_address);
        expect(eth_getprice).to.be.bignumber.equal(etherExp(460).toString())
        const eth_get = await this.priceOracle.get(eth_address)
        expect(eth_get[1]).to.be.bignumber.equal(etherExp(460).toString())
        // console.log(await this.priceOracle.getPrice(eth_address).valueOf())
        // await expectRevert(this.priceOracle.setUnderlyingPrice(eth_address, etherExp(460), {from: bob}),"00");
    });

 });



