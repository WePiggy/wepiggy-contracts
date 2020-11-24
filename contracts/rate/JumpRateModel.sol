// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./BaseJumpRateModel.sol";


/**
  * @title Compound's JumpRateModel Contract V2 for V2 cTokens
  * @author Arr00
  * @notice Supports only for V2 cTokens
  */
contract JumpRateModel is BaseJumpRateModel {

    function initialize(uint baseRatePerYear, uint multiplierPerYear, uint jumpMultiplierPerYear, uint kink_) public initializer {
        super.__Ownable_init();
        super.updateJumpRateModelInternal(baseRatePerYear, multiplierPerYear, jumpMultiplierPerYear, kink_);
    }
}
