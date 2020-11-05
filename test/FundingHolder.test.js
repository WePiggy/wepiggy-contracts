const {accounts, contract} = require('@openzeppelin/test-environment');

// const {
//     expectRevert, // Assertions for transactions that should fail
//     time,
// } = require('@openzeppelin/test-helpers');
const {
  BN,          // Big Number support
  constants,    // Common constants, like the zero address and largest integers
  expectEvent,  // Assertions for emitted events
  expectRevert, // Assertions for transactions that should fail
  time,
} = require('@openzeppelin/test-helpers');

const {expect} = require('chai');

const PiggyToken = contract.fromArtifact('WePiggyToken'); // Loads a compiled contract
const PiggyBreeder = contract.fromArtifact('PiggyBreeder');
const FundingManager = contract.fromArtifact('FundingManager');
const FundingHolder = contract.fromArtifact('FundingHolder');
const MockErc20 = contract.fromArtifact('MockErc20');

describe('FundingHolder', function () {
    const [alice, bob, carol, dev, minter, FH1, FH2, FH3, FH4, FH5] = accounts;
    // this.value = new BN(1000);
    this.timeout(15000);

    beforeEach(async () => {
        this.piggyToken = await PiggyToken.new();
        this.fundingManager = await FundingManager.new(this.piggyToken.address);
        // this.fundingHolder = await FundingHolder.new()
        // this.piggyToken.initialize();
    });


    it('should set correct state variables', async () => {

        this.fundingHolder = await FundingHolder.new(this.piggyToken.address)

        // this.fundingManager = await FundingManager.new(this.piggyToken.address);
        expect(await this.fundingHolder.piggy()).to.equal(this.piggyToken.address);     

    });


    it('should allow owner and only owner to update ', async () => {

        this.FundingHolder = await FundingHolder.new(this.piggyToken.address);

        await expectRevert(this.FundingHolder.transfer('0x0000000000000000000000000000000000000000', '300000', {from: bob}), 'Ownable: caller is not the owner -- Reason given: Ownable: caller is not the owner.');
    });

    context('dev get token and transfer wepiggy tokens to FundingManager', () => {

        beforeEach(async () => {
            this.lp = await MockErc20.new('LPToken', 'LP', '10000000000',{from: minter});
            // this.lp.initialize('LPToken', 'LP', minter, '10000000000');
            await this.lp.transfer(alice, '1000', {from: minter});
            await this.lp.transfer(bob, '1000', {from: minter});
            await this.lp.transfer(carol, '1000', {from: minter});

            this.lp2 = await MockErc20.new('LPToken', 'LP', '10000000000',{from: minter});
            // this.lp2.initialize('LPToken2', 'LP2', minter, '10000000000');
            await this.lp2.transfer(alice, '1000', {from: minter});
            await this.lp2.transfer(bob, '1000', {from: minter});
            await this.lp2.transfer(carol, '1000', {from: minter});

            this.fundingHolder = await FundingHolder.new(this.piggyToken.address)

            this.fundingManager = await FundingManager.new(this.piggyToken.address);

 
            await this.fundingManager.addFunding('InsurancePayment', this.fundingHolder.address ,100)
            

        });

        it('get wepiggy token transfer to FH addresses', async () => {
            this.piggyBreeder = await PiggyBreeder.new(this.piggyToken.address, this.fundingManager.address, '1000000000000000000', '0', '1000', '5760', '999', '39');
            await this.piggyToken.grantRole('0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6', this.piggyBreeder.address);
            await this.piggyBreeder.add('1000', this.lp.address, '0x0000000000000000000000000000000000000000',true);
            await this.lp.approve(this.piggyBreeder.address, '1000', {from: bob});

            await time.advanceBlockTo('30');
            await this.piggyBreeder.stake(0, '100', {from: bob});


            await time.advanceBlockTo('40'); // block 40
            await this.piggyBreeder.stake(0, '100', {from: bob});
            expect(await this.piggyToken.balanceOf(this.fundingManager.address)).to.be.bignumber.equal('3900000000000000000');
            expect(await this.fundingManager.getPendingBalance(0)).to.be.bignumber.equal('3900000000000000000');

            await this.fundingManager.claim()
            // await time.advanceBlockTo('110');
            expect(await this.piggyToken.balanceOf(this.fundingManager.address)).to.be.bignumber.equal('0');
            expect(await this.piggyToken.balanceOf(this.fundingHolder.address)).to.be.bignumber.equal('3900000000000000000');
            // await expectEvent(this.fundingHolder.transfer(carol, '4000000000000000000'), 'Unknown transaction receipt object');
            await this.fundingHolder.transfer(carol, '3900000000000000000');
            expect(await this.piggyToken.balanceOf(this.fundingHolder.address)).to.be.bignumber.equal('0');
            expect(await this.piggyToken.balanceOf(carol)).to.be.bignumber.equal('3900000000000000000');

        });

    });

});
