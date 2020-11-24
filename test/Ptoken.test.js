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

describe('Ptoken', function () {
    const [alice, bob, carol, minter, borrower, customer, faker] = accounts;
    const eth_address = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';
    this.timeout(30000);
    // const opts = {kind: "hello", comptrollerOpts: {kind: "v1-no-proxy"}, supportMarket: true};
    // init comptroller
    beforeEach(async () => {
        this.value = new BN(8);
        this.comptroller = await Comptroller.new();
        this.comptroller.initialize();
        this.DAI = await MockErc20.new('DAI', 'DAI', etherExp(100000000000), {from: minter});
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

    it('should have correct name and symbol and decimal', async () => {
        expect(await this.pEther.name()).to.equal('pETH');
        expect(await this.pEther.symbol()).to.equal('pETH');
        expect(await this.pEther.decimals()).to.be.bignumber.equal(this.value);
        expect(await this.pDAI.name()).to.equal('pDAI');
        expect(await this.pDAI.symbol()).to.equal('pDAI');
        expect(await this.pDAI.decimals()).to.be.bignumber.equal(this.value);
        expect(await this.pBAT.name()).to.equal('pBAT');
        expect(await this.pBAT.symbol()).to.equal('pBAT');
        expect(await this.pBAT.decimals()).to.be.bignumber.equal(this.value);
        
    });

    it('check Ptoken parameters', async () => {
        expect(await this.pEther.interestRateModel()).to.equal(this.jumpRateModel.address);
        expect(await this.pDAI.comptroller()).to.equal(this.comptroller.address);
        expect(await this.pBAT.exchangeRateStored()).to.be.bignumber.equal(etherExp(200000000).toString());
    });

    it('should only allow owner to set setReserveFactor, _setMigrator, _setComptroller, _setInterestRateModel', async () => {
        await expectRevert(this.pEther._setReserveFactor(etherExp(0.1), {from :alice}),"Ownable: caller is not the owner");
        await expectRevert(this.pDAI._setReserveFactor(etherExp(0.1), {from :alice}),"Ownable: caller is not the owner");
        await expectRevert(this.pEther._setMigrator(eth_address, {from :alice}),"Ownable: caller is not the owner");
        await expectRevert(this.pDAI._setComptroller(eth_address, {from :alice}),"Ownable: caller is not the owner");
        await expectRevert(this.pDAI._setInterestRateModel(eth_address, {from :alice}),"Ownable: caller is not the owner");
        
        //owener can set parameters 
        
    });

    context('setting Ptoken parameters', () => {

        beforeEach(async () => {

            //set price

            await this.priceOracle.setPrice(eth_address, etherExp(460));
            await this.priceOracle.setPrice(this.DAI.address,etherExp(1));
            await this.priceOracle.setPrice(this.BAT.address,etherExp(0.0005));
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
            await this.comptroller.enterMarkets([this.pEther.address,this.pDAI.address,this.pBAT.address],{from: minter});
            await this.comptroller.enterMarkets([this.pEther.address,this.pDAI.address,this.pBAT.address],{from: borrower});
            await this.comptroller.enterMarkets([this.pEther.address,this.pDAI.address,this.pBAT.address],{from: customer});
            await this.comptroller.enterMarkets([this.pEther.address,this.pDAI.address,this.pBAT.address],{from: bob});

            await this.pDAI._setReserveFactor(etherExp(0.1));
            await this.pBAT._setReserveFactor(etherExp(0.1));
            await this.pEther._setReserveFactor(etherExp(0.1));
            expect (await this.pDAI.reserveFactorMantissa()).to.be.bignumber.equal(etherExp(0.1).toString());


        });

        it('Ptoken(pETH、PERC20) mint ,repay, borrow,  redeem,liquidity ,verify ', async () => {


            await time.advanceBlockTo('150');

            // bob supply pEth
            await send.transaction(this.pEther, 'mint', '','',{from: bob, value: ether('1'), gas:"5000000", gasPrice:"1000000000"});
            // expect(await web3.eth.getBalance(bob)).to.be.bignumber.equal(etherExp(99).toString());
            expect(await web3.eth.getBalance(this.pEther.address)).to.be.bignumber.equal(etherExp(1).toString())
            expect(await this.pEther.balanceOf(bob)).to.be.bignumber.equal('5000000000');

            //minter supply DAI
            expect(await this.DAI.balanceOf(minter)).to.be.bignumber.equal(etherExp(100000000000).toString());
            this.DAI.approve(this.pDAI.address, etherExp(50000), {from: minter});
            this.pDAI.mint(etherExp(50000),{from: minter});
            expect(await this.DAI.balanceOf(minter)).to.be.bignumber.equal(etherExp(99999950000).toString());
            expect(await this.pDAI.balanceOf(minter)).to.be.bignumber.equal('250000000000000');

            //transfer DAI to customer
            this.DAI.transfer(customer, etherExp(10000), { from: minter });
            expect(await this.DAI.balanceOf(customer)).to.be.bignumber.equal(etherExp(10000).toString());
            expect(await this.DAI.balanceOf(minter)).to.be.bignumber.equal(etherExp(99999940000).toString());

            //borrower supply BAT
            expect(await this.BAT.balanceOf(borrower)).to.be.bignumber.equal(etherExp(10000000000).toString());
            this.BAT.approve(this.pBAT.address, etherExp(500000), {from: borrower});
            this.pBAT.mint(etherExp(500000),{from: borrower});
            expect(await this.BAT.balanceOf(borrower)).to.be.bignumber.equal(etherExp(9999500000).toString());
            expect(await this.pBAT.balanceOf(borrower)).to.be.bignumber.equal('2500000000000000');


            //borrower borrow DAI
            // await time.advanceBlockTo('100');
            await this.pDAI.borrow(etherExp(20), {from: borrower});
            //(uint(Error.NO_ERROR), cTokenBalance, borrowBalance, exchangeRateMantissa)
            let getAccountSnapshot_pDAI,getAccountSnapshot_pBAT;
             getAccountSnapshot_pDAI = await this.pDAI.getAccountSnapshot(borrower);
            expect(getAccountSnapshot_pDAI[2].toString()).equal('20000000000000000000');
            expect(getAccountSnapshot_pDAI[3].toString()).equal('200000000000000000000000000');

            await time.advanceBlockTo('200');
            await this.pDAI.borrow(etherExp(30), {from: borrower});
            getAccountSnapshot_pDAI = await this.pDAI.getAccountSnapshot(borrower);
            expect(getAccountSnapshot_pDAI[2].toString()).equal('50000021007770566622');
            expect(getAccountSnapshot_pDAI[3].toString()).equal('200000000075627974039904000');


            //repay borrow DAI
            this.DAI.approve(this.pDAI.address, etherExp(30), {from: borrower});
            await this.pDAI.repayBorrow(etherExp(30), {from: borrower});
            getAccountSnapshot_pDAI = await this.pDAI.getAccountSnapshot(borrower);
            expect(getAccountSnapshot_pDAI[2].toString()).equal('20000023408536625081');
            expect(getAccountSnapshot_pDAI[3].toString()).equal('200000000084270731850484000');


            //customer supply Dai
            this.DAI.approve(this.pDAI.address, etherExp(30), {from: customer});
            this.pDAI.mint(etherExp(30),{from: customer});
            //(uint(Error.NO_ERROR), cTokenBalance, borrowBalance, exchangeRateMantissa)
            getAccountSnapshot_pDAI = await this.pDAI.getAccountSnapshot(customer);
            expect(getAccountSnapshot_pDAI[1].toString()).equal('149999999934');
            expect(getAccountSnapshot_pDAI[2].toString()).equal('0');
            expect(getAccountSnapshot_pDAI[3].toString()).equal('200000000087708545945339951');

            // borrower continue borrow DAI
            await this.pDAI.borrow(etherExp(128), {from: borrower});
            getAccountSnapshot_pDAI = await this.pDAI.getAccountSnapshot(borrower);
            expect(getAccountSnapshot_pDAI[2].toString()).equal('148000024840885243130');
            expect(getAccountSnapshot_pDAI[3].toString()).equal('200000000089426331076857494');
            expect(await this.DAI.balanceOf(borrower)).to.be.bignumber.equal('148000000000000000000');


            //liquidateBorrow borrower DAI ,liquidated pToken is pBAT
            await this.priceOracle.setPrice(this.BAT.address,etherExp(0.0002));//when the underlying assets BAT Price diving
            this.DAI.approve(this.pDAI.address, etherExp(40), {from: minter});
            this.pDAI.liquidateBorrow(borrower, etherExp(40),this.pBAT.address, {from: minter});
            expect(await this.pBAT.balanceOf(minter)).to.be.bignumber.equal('1050000000000000');


            //should not allow transfer pBAT ,when borrower balance is shortfall
            expect(await this.pBAT.balanceOf(borrower)).to.be.bignumber.equal('1450000000000000');
            await this.pBAT.transfer(minter, '1450000000000000', {from: borrower})
            expect(await this.pBAT.balanceOf(borrower)).to.be.bignumber.equal('1450000000000000');
            expect(await this.pBAT.balanceOf(minter)).to.be.bignumber.equal('1050000000000000');


            
            //minter borrow ETH
            let minterEthBal1,minterEthBal2;
            minterEthBal1 = await web3.eth.getBalance(minter)
            //get ETH cash amount
            expect(await this.pEther.getCash()).to.be.bignumber.equal(ether('1'));
            await this.pEther.borrow(ether('1'), {from: minter});
            minterEthBal2 = await web3.eth.getBalance(minter);
            expect(minterEthBal2).to.be.bignumber.above(minterEthBal1);
            expect(await this.pEther.getCash()).to.be.bignumber.equal(ether('0'));
            expect(await this.pEther.totalBorrows()).to.be.bignumber.equal(ether('1'));
            expect(await this.pEther.totalReserves()).to.be.bignumber.equal(ether('0'));
            expect(await this.pEther.borrowIndex()).to.be.bignumber.equal('1000003662485139641');
            expect(await this.pEther.borrowBalanceStored(minter)).to.be.bignumber.equal(ether('1'));
            expect(await this.pEther.exchangeRateStored()).to.be.bignumber.equal('200000000000000000000000000');



            let borrowBalanceCurrent;
            borrowBalanceCurrent = await this.pEther.borrowBalanceCurrent(minter);

            borrowBalanceCurrent = await this.pEther.borrowBalanceCurrent(bob);

            await time.advanceBlockTo('250');
            expect(await this.pEther.totalBorrows()).to.be.bignumber.equal('1000000487538114066');
            expect(await this.pEther.totalReserves()).to.be.bignumber.equal('48753811406');
            expect(await this.pEther.borrowIndex()).to.be.bignumber.equal('1000004150025039308');
            expect(await this.pEther.borrowBalanceStored(minter)).to.be.bignumber.equal('1000000487538114065');
            expect(await this.pEther.exchangeRateStored()).to.be.bignumber.equal('200000087756860532000000000');
            //console.log(await web3.eth.getBalance(minter));

            //minter repayborrow eth
            await send.transaction(this.pEther, 'repayBorrow', '','',{from: minter, value: ether('1.000004150024060748'), gas:"5000000", gasPrice:"1000000000"});
            expect(await web3.eth.getBalance(this.pEther.address)).to.be.bignumber.equal(ether('1.000004150024060748'));

            // bob redeem ETH
            expect(await this.pEther.balanceOf(bob)).to.be.bignumber.equal('5000000000');
            let bobEthBal1,bobEthBal2;
            bobEthBal1 = await web3.eth.getBalance(bob)
            await this.pEther.redeem('4000000000',{from: bob});
            expect(await this.pEther.balanceOf(bob)).to.be.bignumber.equal('1000000000');
            expect(await web3.eth.getBalance(this.pEther.address)).to.be.bignumber.equal(ether('0.199997129472564576'));

            bobEthBal2 = await web3.eth.getBalance(bob);
            expect(bobEthBal2).to.be.bignumber.above(bobEthBal1);




            // console.log(await web3.eth.getBalance(minter));
            // console.log('1');
            // await time.advanceBlockTo('300');
            // expect(await this.pEther.totalReserves()).to.be.bignumber.equal(ether('0'));
            // console.log(await this.DAI.balanceOf(this.pDAI));
            // await this.pDAI._addReserves('1000');
            // expect(await this.pDAI.totalReserves()).to.be.bignumber.equal('1');




            //redeem DAI
            expect(await this.pDAI.balanceOf(minter)).to.be.bignumber.equal('250000000000000');
            expect(await this.DAI.balanceOf(minter)).to.be.bignumber.equal(etherExp(99999939960).toString());
            await this.pDAI.redeemUnderlying(etherExp(10),{from: minter});
            expect(await this.DAI.balanceOf(minter)).to.be.bignumber.equal(etherExp(99999939970).toString());
            expect(await this.pDAI.balanceOf(minter)).to.be.bignumber.equal('249950000000136');




        });
        it(' mamage totalResevers, addResevers, reduceResvers ', async () => {

            
            await time.advanceBlockTo('350');

            expect(await this.pDAI.totalReserves()).to.be.bignumber.equal('0');
            this.DAI.approve(this.pDAI.address, etherExp(5000000000), {from: minter});
            this.pDAI.mint(etherExp(5000000000),{from: minter});
            await this.pDAI.borrow(etherExp(2000000000), {from: minter});

            await time.advanceBlockTo('1000');
           // AccrueInterest(cashPrior, interestAccumulated, borrowIndexNew, totalBorrowsNew)
            // accrueInterest = await this.pDAI.accrueInterest();
            this.DAI.approve(this.pDAI.address, etherExp(10000000), {from: minter});
            this.pDAI.repayBorrow(etherExp(10000000),{from: minter});
            // borrowBalanceCurrent = await this.pDAI.borrowBalanceCurrent(minter);
            expect(await this.pDAI.totalReserves()).to.be.bignumber.equal('14784857405874600000000');

            // this.DAI.approve(this.pDAI, '1')
            // this.DAI.approve(this.pDAI.address, '1000');
            let owener;
            owener = await this.pDAI.owner();
            await this.DAI.approve(this.pDAI.address, ether('100'), {from: minter});
            await this.pDAI._addReserves(ether('100'), {from: minter});

            expect(await this.DAI.balanceOf(this.pDAI.address)).to.be.bignumber.equal('3010000100000000000000000000')
            expect(await this.DAI.balanceOf(owener)).to.be.bignumber.equal('0')
            await this.pDAI._reduceReserves(ether('100'));
            expect(await this.DAI.balanceOf(this.pDAI.address)).to.be.bignumber.equal('3010000000000000000000000000')
            expect(await this.DAI.balanceOf(owener)).to.be.bignumber.equal('100000000000000000000')



        });


        it(' fake token not allow to mint pTOKEN', async () => {


            this.Faker_DAI = await MockErc20.new('DAI', 'DAI', etherExp(100000000000), {from: faker});
            // this.Faker_ETH = await MockErc20.new('ETH', 'ETH', etherExp(100000000000), {from: faker});
            await this.Faker_DAI.approve(this.pDAI.address, etherExp(30), {from: faker});
            // await this.Faker_ETH.approve(this.pEther.address, etherExp(30), {from: faker});
            await expectRevert (this.pDAI.mint(etherExp(30),{from: faker}), "Reason given: ERC20: transfer amount exceeds balance");
            // await expectRevert (send.transaction(this.pEther, 'mint', '','',{from: bob, value: ether('1'), gas:"5000000", gasPrice:"1000000000"}), "Reason given: ERC20: transfer amount exceeds balance");



        });


    });

 });

