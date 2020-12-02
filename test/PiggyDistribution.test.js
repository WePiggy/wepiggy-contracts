const {accounts, contract, web3} = require('@openzeppelin/test-environment');
const {
  BN,          // Big Number support
  constants,    // Common constants, like the zero address and largest integers
  expectEvent,  // Assertions for emitted events
  expectRevert, // Assertions for transactions that should fail
  send,
  time,
  times,
  balance,
  ether,
} = require('@openzeppelin/test-helpers');
const {
  etherExp,
  etherDouble,
  etherMantissa,
} = require('./Utils/Ethereum');

const ethers = require('ethers');
const {expect} = require('chai');
const pEther = contract.fromArtifact('PERC20'); // Loads a compiled contract
const Comptroller = contract.fromArtifact('Comptroller'); // Loads a compiled contract
const MockErc20 = contract.fromArtifact('MockErc20');
const JumpRateModel = contract.fromArtifact('JumpRateModel');
const PEther = contract.fromArtifact('PEther'); 
const PERC20 = contract.fromArtifact('PERC20'); 
const SimplePriceOracle = contract.fromArtifact('SimplePriceOracle');
const PiggyDistribution = contract.fromArtifact('PiggyDistribution');
const PiggyToken = contract.fromArtifact('WePiggyToken'); // Loads a compiled contract
const PiggyBreeder = contract.fromArtifact('PiggyBreeder');


describe('PiggyDistribution', function () {
    const [alice, bob, carol, minter, dev,borrower, customer, faker, wpcd] = accounts;
    const eth_address = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';
    this.timeout(30000);
    // const opts = {kind: "hello", comptrollerOpts: {kind: "v1-no-proxy"}, supportMarket: true};
    // init comptroller
    beforeEach(async () => {
        this.value = new BN(8);
        // this.WPCDValue = new BN(18)
        this.comptroller = await Comptroller.new();
        this.comptroller.initialize();
        this.DAI = await MockErc20.new('DAI', 'DAI', etherExp(100000000000), {from: minter});
        this.BAT = await MockErc20.new('BAT', 'BAT', etherExp(10000000000), {from: borrower});
        this.piggyDistributerToken = await MockErc20.new('WPCD', 'WPCD', etherExp(1), {from: wpcd});
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
        this.piggyToken = await PiggyToken.new();
        this.piggyBreeder = await PiggyBreeder.new(this.piggyToken.address, dev, '1000000000000000000', '0', '100', '5760', '999', '39');
        this.piggyDistribution = await PiggyDistribution.new();
        this.piggyDistribution.initialize(this.piggyToken.address, this.piggyBreeder.address, this.comptroller.address);
    });

    it('should have correct name and symbol and decimal for PiggyDistributer token ', async () => {
        expect(await this.piggyDistributerToken.name()).to.equal('WPCD');
        expect(await this.piggyDistributerToken.symbol()).to.equal('WPCD');
        expect(await this.piggyDistributerToken.decimals()).to.be.bignumber.equal('18');
        expect(await this.piggyDistributerToken.totalSupply()).to.be.bignumber.equal(ether('1'));

        
    });

    it('check piggyDistribution setting parameters, piggyToken, piggyBreeder, comptroller', async () => {
        expect(await this.piggyDistribution.comptroller()).to.equal(this.comptroller.address);
        expect(await this.piggyDistribution.piggy()).to.equal(this.piggyToken.address);
        expect(await this.piggyDistribution.piggyBreeder()).to.equal(this.piggyBreeder.address);

    });

    it('should only allow owner to set _setWpcRate, _stakeTokenToPiggyBreeder, _addWpcMarkets, _claimWpcFromPiggyBreeder', async () => {
        await expectRevert(this.piggyDistribution._stakeTokenToPiggyBreeder(this.piggyDistributerToken.address, '0', {from :alice}),"Ownable: caller is not the owner");
        await expectRevert(this.piggyDistribution._setWpcRate(etherExp(0.5), {from :alice}),"Ownable: caller is not the owner");
        await expectRevert(this.piggyDistribution._claimWpcFromPiggyBreeder('0', {from :alice}),"Ownable: caller is not the owner");
        await expectRevert(this.piggyDistribution._addWpcMarkets([this.pDAI.address, this.pBAT.address, this.pEther.address], {from :alice}),"Ownable: caller is not the owner");
        
    });

    context('comptroller setting Loan and PiggyDistribution parameters', () => {

        beforeEach(async () => {


            //grantRole piggyBreeder
            await this.piggyToken.grantRole('0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6', this.piggyBreeder.address);
            //add piggyDistributerToken to piggyBreeder
            await this.piggyBreeder.add('1000', this.piggyDistributerToken.address, '0x0000000000000000000000000000000000000000', true);

            //set price

            await this.priceOracle.setPrice(eth_address, etherExp(460));
            await this.priceOracle.setPrice(this.DAI.address,etherExp(1));
            await this.priceOracle.setPrice(this.BAT.address,etherExp(0.0005));
            await this.comptroller._setPriceOracle(this.priceOracle.address);


            //set DistributeWpcPaused false , start DistributeWpc for loan
            
            await this.comptroller._setDistributeWpcPaused(false);


            // set _setPiggyDistribution to start  DistributeWpc for loan
            await this.comptroller._setPiggyDistribution(this.piggyDistribution.address);
             

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
            await this.comptroller.enterMarkets([this.pEther.address,this.pDAI.address,this.pBAT.address],{from: minter});
            await this.comptroller.enterMarkets([this.pEther.address,this.pDAI.address,this.pBAT.address],{from: borrower});
            await this.comptroller.enterMarkets([this.pEther.address,this.pDAI.address,this.pBAT.address],{from: customer});
            await this.comptroller.enterMarkets([this.pEther.address,this.pDAI.address,this.pBAT.address],{from: bob});

            await this.pDAI._setReserveFactor(etherExp(0.1));
            await this.pBAT._setReserveFactor(etherExp(0.1));
            await this.pEther._setReserveFactor(etherExp(0.1));
            expect (await this.pDAI.reserveFactorMantissa()).to.be.bignumber.equal(etherExp(0.1).toString());


            //transfer piggyDistributerToken to piggyDistribution ,and add piggyBreeder
            await this.piggyDistributerToken.transfer(this.piggyDistribution.address, ether('1'), {from: wpcd});

            //piggyDistribution stake to piggyBreeder
            await this.piggyDistribution._stakeTokenToPiggyBreeder(this.piggyDistributerToken.address, '0');

            //setting wpc rate
            await this.piggyDistribution._setWpcRate(etherExp(0.5));

            //add wpc market
            await this.piggyDistribution._addWpcMarkets([this.pDAI.address, this.pBAT.address, this.pEther.address]);

        });

        it('verify Ptoken(pETH、PERC20) mint ,repay, borrow,  redeem,liquidity ,distribute wpc ', async () => {


            // await this.piggyDistribution._refreshWpcSpeeds();


            await time.advanceBlockTo('200');

            expect(await this.piggyBreeder.pendingPiggy(0, this.piggyDistribution.address)).to.be.bignumber.equal('94000000000000000000')

            // bob supply pEth can not trigger distribute wpc
            await send.transaction(this.pEther, 'mint', '','',{from: bob, value: ether('1'), gas:"5000000", gasPrice:"1000000000"});
            await this.piggyDistribution._refreshWpcSpeeds();
            await time.advanceBlockTo('210');
            await this.piggyDistribution.claimWpc(bob);
            expect(await this.piggyDistribution.wpcAccrued(bob)).to.be.bignumber.equal(etherExp(0).toString());
            expect(await this.piggyToken.balanceOf(bob)).to.be.bignumber.equal(etherExp(0).toString());



            //minter supply DAI can not trigger distribute wpc

            this.DAI.approve(this.pDAI.address, etherExp(50000), {from: minter});
            this.pDAI.mint(etherExp(50000),{from: minter});
            await this.piggyDistribution._refreshWpcSpeeds();
            await time.advanceBlockTo('220');
            await this.piggyDistribution.claimWpc(minter);
            expect(await this.piggyDistribution.wpcAccrued(minter)).to.be.bignumber.equal(etherExp(0).toString());
            expect(await this.piggyToken.balanceOf(minter)).to.be.bignumber.equal(etherExp(0).toString());


            //transfer DAI to customer
            this.DAI.transfer(customer, etherExp(10000), { from: minter });
 

            // //borrower supply BAT can not trigger distribute wpc
            // expect(await this.BAT.balanceOf(borrower)).to.be.bignumber.equal(etherExp(10000000000).toString());
            this.BAT.approve(this.pBAT.address, etherExp(500000), {from: borrower});
            this.pBAT.mint(etherExp(500000),{from: borrower});
            await this.piggyDistribution._refreshWpcSpeeds();
            await time.advanceBlockTo('230');
            await this.piggyDistribution.claimWpc(borrower);
            expect(await this.piggyDistribution.wpcAccrued(borrower)).to.be.bignumber.equal(etherExp(0).toString());
            expect(await this.piggyToken.balanceOf(borrower)).to.be.bignumber.equal(etherExp(0).toString());


            //borrower borrow DAI can trigger distribute wpc
            // // await time.advanceBlockTo('100');
            await this.pDAI.borrow(etherExp(20), {from: borrower});
            await this.piggyDistribution._refreshWpcSpeeds();
            await time.advanceBlockTo('240');
            await this.piggyDistribution.claimWpc(borrower);
            expect(await this.piggyDistribution.wpcAccrued(borrower)).to.be.bignumber.equal(etherExp(0).toString());
            expect(await this.piggyToken.balanceOf(borrower)).to.be.bignumber.equal(etherExp(0).toString());
            expect(await this.piggyDistribution.wpcRate()).to.be.bignumber.equal(etherExp(0.5).toString());
            expect(await this.piggyDistribution.wpcSpeeds(this.pDAI.address)).to.be.bignumber.equal(etherExp(0.5).toString());
            let wpcBorrowState = await this.piggyDistribution.wpcBorrowState(this.pDAI.address)
            expect(wpcBorrowState['0']).to.be.bignumber.above(etherExp(0).toString());


            await this.pDAI.borrow(etherExp(30), {from: borrower});
            await this.piggyDistribution.claimWpc(borrower);
            expect(await this.piggyDistribution.wpcAccrued(borrower)).to.be.bignumber.equal('999999999999999998');
            expect(await this.piggyToken.balanceOf(borrower)).to.be.bignumber.equal(etherExp(0).toString());



            //repay borrow DAI 
            this.DAI.approve(this.pDAI.address, etherExp(30), {from: borrower});
            await this.pDAI.repayBorrow(etherExp(30), {from: borrower});
            await this.piggyDistribution.claimWpc(borrower);
            // expect(await this.piggyDistribution.wpcAccrued(borrower)).to.be.bignumber.equal('999999999999999998');
            // expect(await this.piggyToken.balanceOf(borrower)).to.be.bignumber.equal(etherExp(0).toString());

            // getAccountSnapshot_pDAI = await this.pDAI.getAccountSnapshot(borrower);
            // expect(getAccountSnapshot_pDAI[2].toString()).equal('20000023408536625081');
            // expect(getAccountSnapshot_pDAI[3].toString()).equal('200000000084270731850484000');


            //customer supply Dai can not trigger distribute wpc
            this.DAI.approve(this.pDAI.address, etherExp(30), {from: customer});
            this.pDAI.mint(etherExp(30),{from: customer});
            await this.piggyDistribution._refreshWpcSpeeds();
            await this.piggyDistribution.claimWpc(customer);
            expect(await this.piggyDistribution.wpcAccrued(customer)).to.be.bignumber.equal('0');
            expect(await this.piggyToken.balanceOf(customer)).to.be.bignumber.equal(etherExp(0).toString());



            // borrower continue borrow DAI
            await this.pDAI.borrow(etherExp(128), {from: borrower});

            //liquidateBorrow borrower DAI ,liquidated pToken is pBAT , liquidater can not trigger distribute wpc
            await this.priceOracle.setPrice(this.BAT.address,etherExp(0.0002));//when the underlying assets BAT Price diving
            this.DAI.approve(this.pDAI.address, etherExp(40), {from: minter});
            this.pDAI.liquidateBorrow(borrower, etherExp(40),this.pBAT.address, {from: minter});
            await this.piggyDistribution._refreshWpcSpeeds();
            await this.piggyDistribution.claimWpc(minter);
            expect(await this.piggyDistribution.wpcAccrued(minter)).to.be.bignumber.equal('0');
            expect(await this.piggyToken.balanceOf(minter)).to.be.bignumber.equal(etherExp(0).toString());


            //borrow eth can t trigger distribute wpc
            await this.pEther.borrow(ether('0.5'), {from: minter});
            await this.piggyDistribution._refreshWpcSpeeds();
            await this.piggyDistribution.claimWpc(minter);
            expect(await this.piggyDistribution.wpcAccrued(minter)).to.be.bignumber.equal('0');
            expect(await this.piggyToken.balanceOf(minter)).to.be.bignumber.equal(etherExp(0).toString());

            await this.pEther.borrow(ether('0.5'), {from: minter});
            await this.piggyDistribution.claimWpc(minter);
            expect(await this.piggyDistribution.wpcAccrued(minter)).to.be.bignumber.equal('680473328297384136');
            expect(await this.piggyToken.balanceOf(minter)).to.be.bignumber.equal(etherExp(0).toString());

            // redeem eth can not trigger distribute wpc
            await this.pEther.redeem('2000000000',{from: bob});
            await this.piggyDistribution._refreshWpcSpeeds();
            await this.piggyDistribution.claimWpc(bob);
            expect(await this.piggyDistribution.wpcAccrued(bob)).to.be.bignumber.equal('0');
            expect(await this.piggyToken.balanceOf(bob)).to.be.bignumber.equal(etherExp(0).toString());

            await this.pEther.redeem('2000000000',{from: bob});
            await this.piggyDistribution.claimWpc(bob);
            expect(await this.piggyDistribution.wpcAccrued(bob)).to.be.bignumber.equal('0');
            expect(await this.piggyToken.balanceOf(bob)).to.be.bignumber.equal(etherExp(0).toString());



            // distribute wpc 

            await this.piggyDistribution._claimWpcFromPiggyBreeder('0');
            await this.piggyDistribution.claimWpc(minter);
            await this.piggyDistribution.claimWpc(borrower);
            expect(await this.piggyDistribution.wpcAccrued(minter)).to.be.bignumber.equal('0');
            expect(await this.piggyToken.balanceOf(minter)).to.be.bignumber.equal('3385594731630029838');
            expect(await this.piggyDistribution.wpcAccrued(borrower)).to.be.bignumber.equal('0');
            expect(await this.piggyToken.balanceOf(borrower)).to.be.bignumber.equal('9869238989214225750');




        });
        


    });

 });

