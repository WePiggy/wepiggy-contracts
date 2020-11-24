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

const JumpRateModel = contract.fromArtifact('JumpRateModel'); // Loads a compiled contract
const MockErc20 = contract.fromArtifact('MockErc20');


describe('JumpRateModel', function () {
    const [alice, bob, carol] = accounts;
    // const eth_address = '0x0000000000000000000000000000000000000000'
    // const opts = {kind: "hello", comptrollerOpts: {kind: "v1-no-proxy"}, supportMarket: true};

    beforeEach(async () => {
    	this.value = new BN(20000000000000);
      	this.jumpRateModel = await JumpRateModel.new();
      	this.jumpRateModel.initialize(etherExp(0.05),etherExp(0.45),etherExp(0.25),etherExp(0.95));
      	// this.pToken = await MockErc20.new('pToken', 'PT', '10000000000', {from: minter});
      	// this.pETH = await MockErc20.new('pETH', 'pETH', '10000000000', {from: minter});
    });

    it('should only allow owner to operate', async () => {
    	// expect(0).to.be.bignumber.equal(this.value)
        await expectRevert(this.jumpRateModel.transferOwnership(bob, {from :alice}),"Ownable: caller is not the owner");
        await expectRevert(this.jumpRateModel.updateJumpRateModel(etherExp(0.05),etherExp(0.45),etherExp(0.25),etherExp(0.95), {from :alice}),"Ownable: caller is not the owner")
    });

    it('should have corret rate parameters ', async () => {
    	expect(await this.jumpRateModel.blocksPerYear()).to.be.bignumber.equal('2102400');
    	//baseRatePerBlock = baseRatePerYear.div(blocksPerYear)
    	expect(await this.jumpRateModel.baseRatePerBlock()).to.be.bignumber.equal('23782343987');
    	//
    	expect(await this.jumpRateModel.multiplierPerBlock()).to.be.bignumber.equal('225306416726');

    	expect(await this.jumpRateModel.kink()).to.be.bignumber.equal(etherExp(0.95).toString());

    });
    it('get utilizationRate rate ', async () => {
    	// higger than kink 95%
    	let _cash,_borrows,_reserve;
    	_cash = etherExp(100000);
    	_borrows = etherExp(2800000);
    	_reserve = etherExp(1000);
    	expect(await this.jumpRateModel.utilizationRate(_cash, _borrows, _reserve)).to.be.bignumber.equal('965850293204553294');
    	// lower than kink 95%
    	_cash = etherExp(3000000);
    	_borrows = etherExp(2800000);
    	_reserve = etherExp(10);
    	expect(await this.jumpRateModel.utilizationRate(_cash, _borrows, _reserve)).to.be.bignumber.equal('482759453033539712');
    	
    });

    it('get borrow rate', async () => {
    	//higger than kink 95%
    	let _cash,_borrows,_reserve, _borrowRate1, _borrowRate2;
    	_cash = etherExp(100000);
    	_borrows = etherExp(2800000);
    	_reserve = etherExp(1000);
    	console.log(_borrowRate1);
    	expect(await this.jumpRateModel.getBorrowRate(_cash,_borrows,_reserve)).to.be.bignumber.equal('239708225502');
    	//baseRatePerBlock = baseRatePerYear.div(blocksPerYear)
    	_borrowRate1 = new BN('239708225502');
    	// lower than kink 95%
    	_cash = etherExp(3000000);
    	_borrows = etherExp(2800000);
    	_reserve = etherExp(10);
    	expect(await this.jumpRateModel.getBorrowRate(_cash,_borrows,_reserve)).to.be.bignumber.equal('132551146490');
    	_borrowRate2 = new BN('132551146490');
    	//if utilizationRate is more higger , and also the borrowRate is more higger;_borrowRate1 > _borrowRate2 
    	expect(_borrowRate1).to.be.bignumber.above(_borrowRate2);

    });
    it('get supply rate', async () => {
    	//higger than kink 95%-utilizationRate
    	let _cash,_borrows,_reserve, _borrowRate1, _borrowRate2, _supplyRate1, _supplyRate2;
    	_cash = etherExp(100000);
    	_borrows = etherExp(2800000);
    	_reserve = etherExp(1000);
    	_reserveFactor = etherExp(0.1);
    	// console.log(_borrowRate1);
    	expect(await this.jumpRateModel.getBorrowRate(_cash,_borrows,_reserve)).to.be.bignumber.equal('239708225502')
    	//baseRatePerBlock = baseRatePerYear.div(blocksPerYear)
    	_borrowRate1 = new BN('239708225502');

    	expect(await this.jumpRateModel.getSupplyRate(_cash,_borrows,_reserve, _reserveFactor)).to.be.bignumber.equal('208370033895');

    	_supplyRate1 = new BN('208370033895');
    	// borrowRate must be higger than supplyRate ;borrowRate 1> supplyRate1
    	expect(_borrowRate1).to.be.bignumber.above(_supplyRate1);
    	// lower than kink 95%-utilizationRate
    	_cash = etherExp(3000000);
    	_borrows = etherExp(2800000);
    	_reserve = etherExp(10);
    	expect(await this.jumpRateModel.getBorrowRate(_cash,_borrows,_reserve)).to.be.bignumber.equal('132551146490');
    	expect(await this.jumpRateModel.getSupplyRate(_cash,_borrows,_reserve, _reserveFactor)).to.be.bignumber.equal('57591287080');
    	_borrowRate2 = new BN('132551146490');
    	_supplyRate2 = new BN('57591287080');
    	//borrowRate must be higger than supplyRate;_borrowRate2 > _supplyRate2 
    	expect(_borrowRate2).to.be.bignumber.above(_supplyRate2);

    	//if utilizationRate is more higger , and also the supplyRate is more higger; _supplyRate1 > _supplyRate2
    	expect(_supplyRate1).to.be.bignumber.above(_supplyRate2);

    });

 });