// const { expectRevert, time } = require('@openzeppelin/test-helpers');
const {accounts, contract} = require('@openzeppelin/test-environment');
const {
  BN,          // Big Number support
  constants,    // Common constants, like the zero address and largest integers
  expectEvent,  // Assertions for emitted events
  expectRevert, // Assertions for transactions that should fail
  time,
} = require('@openzeppelin/test-helpers');

const {expect} = require('chai');
const ethers = require('ethers');
const WePiggyToken = contract.fromArtifact('WePiggyToken');
const PiggyBreeder = contract.fromArtifact('PiggyBreeder');
const MockERC20 = contract.fromArtifact('MockERC20');
const Timelock = contract.fromArtifact('Timelock');

function encodeParameters(types, values) {
    const abi = new ethers.utils.AbiCoder();
    return abi.encode(types, values);
}

describe('Timelock', function () {
    const [alice, bob, carol, minter] = accounts;
    beforeEach(async () => {
        this.piggyToken = await WePiggyToken.new();
        this.timelock = await Timelock.new(bob, '259200');
    });

    it('should not allow non-owner to do operation', async () => {
        await this.piggyToken.grantRole('0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6', alice);
        await expectRevert(
            this.piggyToken.grantRole('0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6', carol,{ from: alice }),
            'AccessControl: sender must be an admin to grant',
        );
        await expectRevert(
            this.piggyToken.grantRole('0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6',carol, { from: bob }),
            'AccessControl: sender must be an admin to grant',
        );
        await expectRevert(
            this.timelock.queueTransaction(
                this.piggyToken.address, '0', 'grantRole(bytes32,address)',
                encodeParameters(['bytes32','address'], ['0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6',carol]),
                (await time.latest()).add(time.duration.days(4)),
                { from: alice },
            ),
            'Timelock::queueTransaction: Call must come from admin.',
        );
    });

    it('should do the timelock thing', async () => {
        await this.piggyToken.grantRole('0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6',alice);
        const eta = (await time.latest()).add(time.duration.days(4));
        // expect(eta).to.be.bignumber.equal('123344444');
        await this.timelock.queueTransaction(
            this.piggyToken.address, '0', 'grantRole(bytes32,address)',
            encodeParameters(['bytes32','address'], ['0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6',carol]), eta, { from: bob },
        );
        await time.increase(time.duration.days(1));
        await expectRevert(
            this.timelock.executeTransaction(
                this.piggyToken.address, '0', 'grantRole(bytes32,address)',
                encodeParameters(['bytes32','address'], ['0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6',carol]), eta, { from: bob },
            ),
            "Timelock::executeTransaction: Transaction hasn't surpassed time lock.",
        );
    });

    it('should also work with PiggyBreeder', async () => {
        this.lp1 = await MockERC20.new('LPToken', 'LP', '10000000000', { from: minter });
        this.lp2 = await MockERC20.new('LPToken', 'LP', '10000000000', { from: minter });
        this.piggyBreeder = await PiggyBreeder.new(this.piggyToken.address, carol, '1000000000000000000', '0', '1000', '5760', '999', '39');
        // // await this.piggyToken.transferOwnership(this.piggyBreeder.address, { from: alice });
        await this.piggyToken.grantRole('0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6', this.piggyBreeder.address);
        await this.piggyBreeder.add('100', this.lp1.address, '0x0000000000000000000000000000000000000000', true);
        // // await this.piggyBreeder.add('100', this.lp1.address, true);
        await this.piggyBreeder.transferOwnership(this.timelock.address);
        const eta = (await time.latest()).add(time.duration.days(4));
        await this.timelock.queueTransaction(
            this.piggyBreeder.address, '0', 'setAllocPoint(uint256,uint256,bool)',
            encodeParameters(['uint256', 'uint256', 'bool'], ['0', '200', true]), eta, { from: bob },
        );
        await this.timelock.queueTransaction(
            this.piggyBreeder.address, '0', 'add(uint256,address,address,bool)',
            encodeParameters(['uint256', 'address', 'address','bool'], ['100', this.lp2.address, '0x0000000000000000000000000000000000000000',true]), eta, { from: bob },
        );
        await time.increase(time.duration.days(4));
        await this.timelock.executeTransaction(
            this.piggyBreeder.address, '0', 'setAllocPoint(uint256,uint256,bool)',
            encodeParameters(['uint256', 'uint256', 'bool'], ['0', '200', true]), eta, { from: bob },
        );
        await this.timelock.executeTransaction(
            this.piggyBreeder.address, '0', 'add(uint256,address,address,bool)',
            encodeParameters(['uint256', 'address', 'address','bool'], ['100', this.lp2.address, '0x0000000000000000000000000000000000000000',true]), eta, { from: bob },
        );

        expect((await this.piggyBreeder.poolInfo('0')).valueOf().allocPoint).to.be.bignumber.equal('200')
        expect((await this.piggyBreeder.poolInfo('1')).valueOf().allocPoint).to.be.bignumber.equal('100')
        expect((await this.piggyBreeder.totalAllocPoint()).valueOf()).to.be.bignumber.equal('300')
        expect((await this.piggyBreeder.poolLength()).valueOf()).to.be.bignumber.equal('2')
    });
});
