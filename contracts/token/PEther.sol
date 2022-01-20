// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./PToken.sol";
import "../flashloan/IFlashloan.sol";

contract PEther is PToken {

    IFlashloan public flashloanInstance;

    function initialize(IComptroller comptroller_,
        IInterestRateModel interestRateModel_,
        uint initialExchangeRateMantissa_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_) public initializer {
        super.__Ownable_init();
        super.init(comptroller_, interestRateModel_, initialExchangeRateMantissa_, name_, symbol_, decimals_);
    }

    function mint() external payable {
        (uint err,) = mintInternal(msg.value);
        requireNoError(err, "mint failed");
    }

    function mintForMigrate(uint mintTokens) external payable {
        (uint err,) = mintInternalForMigrate(msg.value, mintTokens);
        requireNoError(err, "mint failed");
    }

    function redeem(uint redeemTokens) external returns (uint) {
        return redeemInternal(redeemTokens);
    }

    function redeemUnderlying(uint redeemAmount) external returns (uint) {
        return redeemUnderlyingInternal(redeemAmount);
    }

    function borrow(uint borrowAmount) external returns (uint) {
        return borrowInternal(borrowAmount);
    }

    function repayBorrow() external payable {
        (uint err,) = repayBorrowInternal(msg.value);
        requireNoError(err, "repayBorrow failed");
    }

    function repayBorrowBehalf(address borrower) external payable {
        (uint err,) = repayBorrowBehalfInternal(borrower, msg.value);
        requireNoError(err, "repayBorrowBehalf failed");
    }

    function liquidateBorrow(address borrower, PToken pTokenCollateral) external payable {
        (uint err,) = liquidateBorrowInternal(borrower, msg.value, pTokenCollateral);
        requireNoError(err, "liquidateBorrow failed");
    }

    receive() external payable {
    }

    function getCashPrior() internal override view returns (uint) {
        (MathError err, uint startingBalance) = subUInt(address(this).balance, msg.value);
        require(err == MathError.NO_ERROR);
        return startingBalance;
    }

    function doTransferIn(address from, uint amount) internal override returns (uint) {
        require(msg.sender == from, "sender mismatch");
        require(msg.value == amount, "value mismatch");
        return amount;
    }

    function doTransferOut(address payable to, uint amount) internal override {
        to.transfer(amount);
    }

    function requireNoError(uint errCode, string memory message) internal pure {
        if (errCode == uint(Error.NO_ERROR)) {
            return;
        }
        bytes memory fullMessage = new bytes(bytes(message).length + 5);
        uint i;
        for (i = 0; i < bytes(message).length; i++) {
            fullMessage[i] = bytes(message)[i];
        }
        fullMessage[i + 0] = byte(uint8(32));
        fullMessage[i + 1] = byte(uint8(40));
        fullMessage[i + 2] = byte(uint8(48 + (errCode / 10)));
        fullMessage[i + 3] = byte(uint8(48 + (errCode % 10)));
        fullMessage[i + 4] = byte(uint8(41));
        require(errCode == uint(Error.NO_ERROR), string(fullMessage));
    }

    function flashloan(address _receiver, uint256 _amount, bytes memory _params) nonReentrant external {
        uint256 cashBefore = getCashPrior();
        address payable fl = address(uint160(address(flashloanInstance)));
        doTransferOut(fl, _amount);
        flashloanInstance.flashloan(address(this), _receiver, address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), _amount, _params);
        require(getCashPrior() >= cashBefore, "The actual balance is inconsistent");
        accrueInterest();
    }

    function _setFlashloan(address _flashloan) public onlyOwner {
        flashloanInstance = IFlashloan(_flashloan);
    }

}
