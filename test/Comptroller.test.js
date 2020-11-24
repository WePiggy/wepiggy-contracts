const {accounts, contract, web3} = require('@openzeppelin/test-environment');
const {
  BN,          // Big Number support
  constants,    // Common constants, like the zero address and largest integers
  expectEvent,  // Assertions for emitted events
  expectRevert, // Assertions for transactions that should fail
  time,
  send,
  balance,
  ether,
} = require('@openzeppelin/test-helpers');

const {
  etherExp,
  etherDouble,
  etherMantissa,
} = require('./Utils/Ethereum');

const {expect} = require('chai');
const ethers = require('ethers');

const Comptroller = contract.fromArtifact('Comptroller'); // Loads a compiled contract
const MockErc20 = contract.fromArtifact('MockErc20');
const JumpRateModel = contract.fromArtifact('JumpRateModel');
const PEther = contract.fromArtifact('PEther'); 
const PERC20 = contract.fromArtifact('PERC20'); 
const SimplePriceOracle = contract.fromArtifact('SimplePriceOracle');

describe('Comptroller', function () {
    const [alice, bob, carol, minter, borrower] = accounts;
    const eth_address = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';
    this.timeout(15000);
    // const opts = {kind: "hello", comptrollerOpts: {kind: "v1-no-proxy"}, supportMarket: true};

    beforeEach(async () => {
    	this.one_ether = new BN(18);
        this.comptroller = await Comptroller.new();
        this.comptroller.initialize();
        this.DAI = await MockErc20.new('DAI', 'DAI', etherExp(100000), {from: minter});
        this.BAT = await MockErc20.new('BAT', 'BAT', etherExp(10000000000), {from: borrower});
        this.jumpRateModel = await JumpRateModel.new();
      	this.jumpRateModel.initialize(etherExp(0.05),etherExp(0.45),etherExp(0.25),etherExp(0.95));
        this.priceOracle = await SimplePriceOracle.new();
      	this.priceOracle.initialize();
      	this.pEther = await PEther.new();
        this.pEther.initialize(this.comptroller.address, this.jumpRateModel.address, etherExp(200000000),'pETH','pETH','8');
        this.pDAI = await PERC20.new();
        this.pDAI.initialize(this.DAI.address, this.comptroller.address, this.jumpRateModel.address, etherExp(200000000),'pDAI','pDAI','8');
        this.pBAT = await PERC20.new();
        this.pBAT.initialize(this.BAT.address, this.comptroller.address, this.jumpRateModel.address, etherExp(200000000),'pBAT','pBAT','8');
    });

    it('should only allow owner to set price or uderlyingPrice', async () => {
        await expectRevert(this.comptroller._setPriceOracle(eth_address, {from :alice}),"Ownable: caller is not the owner");
        await expectRevert(this.comptroller._supportMarket(eth_address, {from :alice}),"Ownable: caller is not the owner");
        await expectRevert(this.comptroller._setMaxAssets('10', {from :alice}),"Ownable: caller is not the owner");
        await expectRevert(this.comptroller._setCollateralFactor(eth_address,etherExp(0.75), {from :alice}),"Ownable: caller is not the owner");
        await expectRevert(this.comptroller._setCloseFactor(etherExp(0.5), {from :alice}),"Ownable: caller is not the owner");
        await expectRevert(this.comptroller._setLiquidationIncentive(etherExp(1.05), {from :alice}),"Ownable: caller is not the owner");
        // await expectRevert(this.comptroller._setReserveFactor(etherExp(0.1), {from :alice}),"Ownable: caller is not the owner")
    });

	context('setting comptroller parameters', () => {

		beforeEach(async () => {

			//set price

			await this.priceOracle.setPrice(eth_address, etherExp(460));
	    	expect(await this.priceOracle.getUnderlyingPrice(this.pEther.address)).to.be.bignumber.equal(etherExp(460).toString());
	    	await this.priceOracle.setPrice(this.DAI.address,etherExp(1));
	    	expect(await this.priceOracle.getUnderlyingPrice(this.pDAI.address)).to.be.bignumber.equal(etherExp(1).toString());
	    	await this.priceOracle.setPrice(this.BAT.address,etherExp(0.0005));
	    	expect(await this.priceOracle.getUnderlyingPrice(this.pBAT.address)).to.be.bignumber.equal(etherExp(0.0005).toString());
	    	await this.comptroller._setPriceOracle(this.priceOracle.address);


	    	//set DistributeWpcPaused true 
	    	
	    	 await this.comptroller._setDistributeWpcPaused(true);
	    	 
	        // add supportMarket
	        await this.comptroller._supportMarket(this.pEther.address);
	        await this.comptroller._supportMarket(this.pDAI.address);
	        await this.comptroller._supportMarket(this.pBAT.address);

	        // set max assets
	        await this.comptroller._setMaxAssets('10');
	        await this.comptroller._setCollateralFactor(this.pDAI.address,etherExp(0.6));
	        await this.comptroller._setCollateralFactor(this.pEther.address,etherExp(0.75));
	        await this.comptroller._setCollateralFactor(this.pBAT.address,etherExp(0.6));
	        await this.comptroller._setCloseFactor(etherExp(0.5));
	        await this.comptroller._setLiquidationIncentive(etherExp(1.05));
	        // enter collateral makerts
	        await this.comptroller.enterMarkets([this.pEther.address,this.pDAI.address,this.pBAT.address],{from: minter})
	        await this.comptroller.enterMarkets([this.pEther.address,this.pDAI.address,this.pBAT.address],{from: borrower})


		});


	    it('should check settings', async () => {
	    	// await this.priceOracle.setPrice(eth_address, etherExp(460));
	    	expect(await this.priceOracle.getUnderlyingPrice(this.pEther.address)).to.be.bignumber.equal(etherExp(460).toString());
	    	// await this.priceOracle.setPrice(this.DAI.address,etherExp(1));
	    	expect(await this.priceOracle.getUnderlyingPrice(this.pDAI.address)).to.be.bignumber.equal(etherExp(1).toString());
	    	// console.log(this.priceOracle.address);
	    	expect(await this.comptroller.oracle()).equal(this.priceOracle.address);
	    	expect(await this.comptroller.maxAssets()).to.be.bignumber.equal('10');
	    	// expect(await this.comptroller.maxAssets()).to.be.bignumber.equal('10');
	    	expect(await this.comptroller.closeFactorMantissa()).to.be.bignumber.equal(etherExp(0.5).toString());
	    	expect(await this.comptroller.liquidationIncentiveMantissa()).to.be.bignumber.equal(etherExp(1.05).toString());
	    	// await this.comptroller._setPriceOracle(this.priceOracle.address);

	    });

	    it('comptroller mint , liquidity ,accountLiquidity verify ', async () => {
	    	
	    	// console.log(this.pEther.abi)
	    	// send.ether(bob,this.pEther.address, ether('20'));
	    	// const tracker = await balance.tracker(this.pEther.address, 'ether')
			// await send.ether(bob, this.pEther.address, ether('1'), {from:bob})
			// (await tracker.delta()).should.be.bignumber.equal('10');
			// (await tracker.delta()).should.be.bignumber.equal('0');
	    	// send.ether(bob, this.pEther.address, new BN('100000000000'));
	    	//{
	    	await send.transaction(this.pEther, 'mint', '','',{from: bob, value: ether('1'), gas:"5000000", gasPrice:"1000000000"});
	    	// expect(await web3.eth.getBalance(bob)).to.be.bignumber.equal(etherExp(99).toString());
	    	expect(await web3.eth.getBalance(this.pEther.address)).to.be.bignumber.equal(etherExp(1).toString())
	    	expect(await this.pEther.balanceOf(bob)).to.be.bignumber.equal('5000000000');



	    	expect(await this.DAI.balanceOf(minter)).to.be.bignumber.equal(etherExp(100000).toString());
	    	this.DAI.approve(this.pDAI.address, etherExp(50000), {from: minter});
	    	this.pDAI.mint(etherExp(50000),{from: minter});
	    	expect(await this.DAI.balanceOf(minter)).to.be.bignumber.equal(etherExp(50000).toString());
	    	expect(await this.pDAI.balanceOf(minter)).to.be.bignumber.equal('250000000000000');


	    	expect(await this.BAT.balanceOf(borrower)).to.be.bignumber.equal(etherExp(10000000000).toString());
	    	this.BAT.approve(this.pBAT.address, etherExp(500000), {from: borrower});
	    	this.pBAT.mint(etherExp(500000),{from: borrower});
	    	expect(await this.BAT.balanceOf(borrower)).to.be.bignumber.equal(etherExp(9999500000).toString());
	    	expect(await this.pBAT.balanceOf(borrower)).to.be.bignumber.equal('2500000000000000');

	    	await this.pDAI.borrow(etherExp(149), {from: borrower});
	    	expect(await this.DAI.balanceOf(borrower)).to.be.bignumber.equal(etherExp(149).toString());
	    	let accountLiquidity = await this.comptroller.getAccountLiquidity(borrower)
	    	// expect(accountLiquidity[0].toString()).equal('0');
	    	expect(accountLiquidity[1].toString()).equal('1000000000000000000');
	    	expect(accountLiquidity[2].toString()).equal('0');


	    	await this.priceOracle.setPrice(this.BAT.address,etherExp(0.0002));
	    	expect(await this.priceOracle.getUnderlyingPrice(this.pBAT.address)).to.be.bignumber.equal(etherExp(0.0002).toString());
	    	let accountLiquidity2 = await this.comptroller.getAccountLiquidity(borrower)
	    	// expect(accountLiquidity2[0].toString()).equal('0');
	    	expect(accountLiquidity2[1].toString()).equal('0');
	    	expect(accountLiquidity2[2].toString()).equal('89000000000000000000');
	    	expect(await this.pBAT.balanceOf(minter)).to.be.bignumber.equal('0');


	    });

	it('exit market', async () => {

		// console.log(this.pEther.address)
  //   	console.log(this.pDAI.address)
  //   	console.log(this.pBAT.address)
  //   	console.log(this.DAI.address)
  //   	console.log(this.BAT.address)

		let getassetsIn1,getassetsIn2;
		getassetsIn1 = await this.comptroller.getAssetsIn(minter);
		expect(getassetsIn1[0]).equal(this.pEther.address);
		expect(getassetsIn1.length).equal(3);

		await this.comptroller.exitMarket(this.pEther.address,{from: minter});

		getassetsIn2 = await this.comptroller.getAssetsIn(minter)
		expect(getassetsIn2.length).equal(2);


	    });

	});

 });
