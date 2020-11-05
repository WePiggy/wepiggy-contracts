const {accounts, contract} = require('@openzeppelin/test-environment');
const {
  BN,          // Big Number support
  constants,    // Common constants, like the zero address and largest integers
  expectEvent,  // Assertions for emitted events
  expectRevert, // Assertions for transactions that should fail
} = require('@openzeppelin/test-helpers');

const {expect} = require('chai');

const PiggyToken = contract.fromArtifact('WePiggyToken'); // Loads a compiled contract

describe('PiggyToken', function () {
    const [alice, bob, carol] = accounts;

    beforeEach(async () => {
    	this.value = new BN(18);
        this.piggyToken = await PiggyToken.new();
        // this.piggyToken.initialize();
    });

    it('should have correct name and symbol and decimal', async () => {
    	// const name = await this.piggyToken.name();
     //    const symbol = await this.piggyToken.symbol();
     //    const decimals = await this.piggyToken.decimals();
     //    assert.equal(name.valueOf(), 'HundredToken');
     //    assert.equal(symbol.valueOf(), 'HUNDRED');
     //    assert.equal(decimals.valueOf(), '18');
    	// assert.equal()
        expect(await this.piggyToken.name()).to.equal('WePiggy Coin');
        expect(await this.piggyToken.symbol()).to.equal('WPC');
        expect(await this.piggyToken.decimals()).to.be.bignumber.equal(this.value);
    });
 
    it('should only allow owner to mint token', async () => {

        await this.piggyToken.grantRole('0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6', alice);
        await this.piggyToken.mint(alice, '1000', {from: alice});
        await this.piggyToken.mint(bob, '10000', {from: alice});
        await expectRevert(
            this.piggyToken.mint(carol, '1000', {from: bob }),
            'Caller is not a minter',
        );
        expect(await this.piggyToken.balanceOf(alice)).to.be.bignumber.equal('1000');
        expect(await this.piggyToken.balanceOf(bob)).to.be.bignumber.equal('10000');
        expect(await this.piggyToken.balanceOf(carol)).to.be.bignumber.equal('0');
        expect(await this.piggyToken.totalSupply()).to.be.bignumber.equal('11000');

    });

    it('should supply token transfers properly', async () => {
    	await this.piggyToken.grantRole('0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6', alice);
        await this.piggyToken.mint(alice, '100', { from: alice });
        await this.piggyToken.mint(bob, '1000', { from: alice });
        await this.piggyToken.transfer(carol, '10', { from: alice });
        await this.piggyToken.transfer(carol, '100', { from: bob });
        const totalSupply = await this.piggyToken.totalSupply();
        const aliceBal = await this.piggyToken.balanceOf(alice);
        const bobBal = await this.piggyToken.balanceOf(bob);
        const carolBal = await this.piggyToken.balanceOf(carol);
        expect(totalSupply.valueOf()).to.be.bignumber.equal('1100');
        expect(aliceBal.valueOf()).to.be.bignumber.equal('90');
        expect(bobBal.valueOf()).to.be.bignumber.equal('900');
        expect(carolBal.valueOf()).to.be.bignumber.equal('110');
    });

    it('should fail if you try to do bad transfers', async () => {
    	await this.piggyToken.grantRole('0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6', alice);
        await this.piggyToken.mint(alice, '100', { from: alice });
        await expectRevert(
            this.piggyToken.transfer(carol, '110', { from: alice }),
            'ERC20: transfer amount exceeds balance',
        );
        await expectRevert(
            this.piggyToken.transfer(carol, '1', { from: bob }),
            'ERC20: transfer amount exceeds balance',
        );
    });

});


