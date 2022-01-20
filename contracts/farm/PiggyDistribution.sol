pragma solidity 0.6.12;

import "../libs/Exponential.sol";
import "../token/PToken.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "../comptroller/ComptrollerStorage.sol";
import "../comptroller/Comptroller.sol";
import "../comptroller/ComptrollerStorage.sol";

interface IPiggyDistribution {

    function distributeMintWpc(address pToken, address minter, bool distributeAll) external;

    function distributeRedeemWpc(address pToken, address redeemer, bool distributeAll) external;

    function distributeBorrowWpc(address pToken, address borrower, bool distributeAll) external;

    function distributeRepayBorrowWpc(address pToken, address borrower, bool distributeAll) external;

    function distributeSeizeWpc(address pTokenCollateral, address borrower, address liquidator, bool distributeAll) external;

    function distributeTransferWpc(address pToken, address src, address dst, bool distributeAll) external;

}

interface IPiggyBreeder {
    function stake(uint256 _pid, uint256 _amount) external;

    function unStake(uint256 _pid, uint256 _amount) external;

    function claim(uint256 _pid) external;

    function emergencyWithdraw(uint256 _pid) external;
}

contract PiggyDistribution is IPiggyDistribution, Exponential, OwnableUpgradeSafe {

    IERC20 public piggy;

    IPiggyBreeder public piggyBreeder;

    Comptroller public comptroller;

    //PIGGY-MODIFY: Copy and modify from ComptrollerV3Storage

    struct WpcMarketState {
        /// @notice The market's last updated compBorrowIndex or compSupplyIndex
        uint224 index;

        /// @notice The block number the index was last updated at
        uint32 block;
    }

    /// @notice The portion of compRate that each market currently receives
    mapping(address => uint) public wpcSpeeds;

    /// @notice The WPC market supply state for each market
    mapping(address => WpcMarketState) public wpcSupplyState;

    /// @notice The WPC market borrow state for each market
    mapping(address => WpcMarketState) public wpcBorrowState;

    /// @notice The WPC borrow index for each market for each supplier as of the last time they accrued WPC
    mapping(address => mapping(address => uint)) public wpcSupplierIndex;

    /// @notice The WPC borrow index for each market for each borrower as of the last time they accrued WPC
    mapping(address => mapping(address => uint)) public wpcBorrowerIndex;

    /// @notice The WPC accrued but not yet transferred to each user
    mapping(address => uint) public wpcAccrued;

    /// @notice The threshold above which the flywheel transfers WPC, in wei
    uint public constant wpcClaimThreshold = 0.001e18;

    /// @notice The initial WPC index for a market
    uint224 public constant wpcInitialIndex = 1e36;

    bool public enableWpcClaim;
    bool public enableDistributeMintWpc;
    bool public enableDistributeRedeemWpc;
    bool public enableDistributeBorrowWpc;
    bool public enableDistributeRepayBorrowWpc;
    bool public enableDistributeSeizeWpc;
    bool public enableDistributeTransferWpc;


    /// @notice Emitted when a new WPC speed is calculated for a market
    event WpcSpeedUpdated(PToken indexed pToken, uint newSpeed);

    /// @notice Emitted when WPC is distributed to a supplier
    event DistributedSupplierWpc(PToken indexed pToken, address indexed supplier, uint wpcDelta, uint wpcSupplyIndex);

    /// @notice Emitted when WPC is distributed to a borrower
    event DistributedBorrowerWpc(PToken indexed pToken, address indexed borrower, uint wpcDelta, uint wpcBorrowIndex);

    event StakeTokenToPiggyBreeder(IERC20 token, uint pid, uint amount);

    event ClaimWpcFromPiggyBreeder(uint pid);

    event EnableState(string action, bool state);

    function initialize(IERC20 _piggy, IPiggyBreeder _piggyBreeder, Comptroller _comptroller) public initializer {

        piggy = _piggy;
        piggyBreeder = _piggyBreeder;
        comptroller = _comptroller;

        enableWpcClaim = false;
        enableDistributeMintWpc = false;
        enableDistributeRedeemWpc = false;
        enableDistributeBorrowWpc = false;
        enableDistributeRepayBorrowWpc = false;
        enableDistributeSeizeWpc = false;
        enableDistributeTransferWpc = false;

        super.__Ownable_init();
    }

    function distributeMintWpc(address pToken, address minter, bool distributeAll) public override(IPiggyDistribution) {
        require(msg.sender == address(comptroller) || msg.sender == owner(), "only comptroller or owner");
        if (enableDistributeMintWpc) {
            updateWpcSupplyIndex(pToken);
            distributeSupplierWpc(pToken, minter, distributeAll);
        }
    }

    function distributeRedeemWpc(address pToken, address redeemer, bool distributeAll) public override(IPiggyDistribution) {
        require(msg.sender == address(comptroller) || msg.sender == owner(), "only comptroller or owner");
        if (enableDistributeRedeemWpc) {
            updateWpcSupplyIndex(pToken);
            distributeSupplierWpc(pToken, redeemer, distributeAll);
        }
    }

    function distributeBorrowWpc(address pToken, address borrower, bool distributeAll) public override(IPiggyDistribution) {

        require(msg.sender == address(comptroller) || msg.sender == owner(), "only comptroller or owner");

        if (enableDistributeBorrowWpc) {
            Exp memory borrowIndex = Exp({mantissa : PToken(pToken).borrowIndex()});
            updateWpcBorrowIndex(pToken, borrowIndex);
            distributeBorrowerWpc(pToken, borrower, borrowIndex, distributeAll);
        }


    }

    function distributeRepayBorrowWpc(address pToken, address borrower, bool distributeAll) public override(IPiggyDistribution) {

        require(msg.sender == address(comptroller) || msg.sender == owner(), "only comptroller or owner");

        if (enableDistributeRepayBorrowWpc) {
            Exp memory borrowIndex = Exp({mantissa : PToken(pToken).borrowIndex()});
            updateWpcBorrowIndex(pToken, borrowIndex);
            distributeBorrowerWpc(pToken, borrower, borrowIndex, distributeAll);
        }

    }

    function distributeSeizeWpc(address pTokenCollateral, address borrower, address liquidator, bool distributeAll) public override(IPiggyDistribution) {

        require(msg.sender == address(comptroller) || msg.sender == owner(), "only comptroller or owner");

        if (enableDistributeSeizeWpc) {
            updateWpcSupplyIndex(pTokenCollateral);
            distributeSupplierWpc(pTokenCollateral, borrower, distributeAll);
            distributeSupplierWpc(pTokenCollateral, liquidator, distributeAll);
        }

    }

    function distributeTransferWpc(address pToken, address src, address dst, bool distributeAll) public override(IPiggyDistribution) {

        require(msg.sender == address(comptroller) || msg.sender == owner(), "only comptroller or owner");

        if (enableDistributeTransferWpc) {
            updateWpcSupplyIndex(pToken);
            distributeSupplierWpc(pToken, src, distributeAll);
            distributeSupplierWpc(pToken, dst, distributeAll);
        }

    }

    function _stakeTokenToPiggyBreeder(IERC20 token, uint pid) public onlyOwner {
        uint amount = token.balanceOf(address(this));
        token.approve(address(piggyBreeder), amount);
        piggyBreeder.stake(pid, amount);
        emit StakeTokenToPiggyBreeder(token, pid, amount);
    }

    function _claimWpcFromPiggyBreeder(uint pid) public onlyOwner {
        piggyBreeder.claim(pid);
        emit ClaimWpcFromPiggyBreeder(pid);
    }

    function setWpcSpeedInternal(PToken pToken, uint wpcSpeed) internal {
        uint currentWpcSpeed = wpcSpeeds[address(pToken)];
        if (currentWpcSpeed != 0) {
            // note that WPC speed could be set to 0 to halt liquidity rewards for a market
            Exp memory borrowIndex = Exp({mantissa : pToken.borrowIndex()});
            updateWpcSupplyIndex(address(pToken));
            updateWpcBorrowIndex(address(pToken), borrowIndex);
        } else if (wpcSpeed != 0) {

            require(comptroller.isMarketListed(address(pToken)), "wpc market is not listed");

            if (comptroller.isMarketMinted(address(pToken)) == false) {
                comptroller._setMarketMinted(address(pToken), true);
            }

            if (wpcSupplyState[address(pToken)].index == 0 && wpcSupplyState[address(pToken)].block == 0) {
                wpcSupplyState[address(pToken)] = WpcMarketState({
                index : wpcInitialIndex,
                block : safe32(block.number, "block number exceeds 32 bits")
                });
            }

            if (wpcBorrowState[address(pToken)].index == 0 && wpcBorrowState[address(pToken)].block == 0) {
                wpcBorrowState[address(pToken)] = WpcMarketState({
                index : wpcInitialIndex,
                block : safe32(block.number, "block number exceeds 32 bits")
                });
            }

        }

        if (currentWpcSpeed != wpcSpeed) {
            wpcSpeeds[address(pToken)] = wpcSpeed;
            emit WpcSpeedUpdated(pToken, wpcSpeed);
        }

    }

    /**
     * @notice Accrue WPC to the market by updating the supply index
     * @param pToken The market whose supply index to update
     */
    function updateWpcSupplyIndex(address pToken) internal {
        WpcMarketState storage supplyState = wpcSupplyState[pToken];
        uint supplySpeed = wpcSpeeds[pToken];
        uint blockNumber = block.number;
        uint deltaBlocks = sub_(blockNumber, uint(supplyState.block));
        if (deltaBlocks > 0 && supplySpeed > 0) {
            uint supplyTokens = PToken(pToken).totalSupply();
            uint wpcAccrued = mul_(deltaBlocks, supplySpeed);
            Double memory ratio = supplyTokens > 0 ? fraction(wpcAccrued, supplyTokens) : Double({mantissa : 0});
            Double memory index = add_(Double({mantissa : supplyState.index}), ratio);
            wpcSupplyState[pToken] = WpcMarketState({
            index : safe224(index.mantissa, "new index exceeds 224 bits"),
            block : safe32(blockNumber, "block number exceeds 32 bits")
            });
        } else if (deltaBlocks > 0) {
            supplyState.block = safe32(blockNumber, "block number exceeds 32 bits");
        }
    }

    /**
     * @notice Accrue WPC to the market by updating the borrow index
     * @param pToken The market whose borrow index to update
     */
    function updateWpcBorrowIndex(address pToken, Exp memory marketBorrowIndex) internal {
        WpcMarketState storage borrowState = wpcBorrowState[pToken];
        uint borrowSpeed = wpcSpeeds[pToken];
        uint blockNumber = block.number;
        uint deltaBlocks = sub_(blockNumber, uint(borrowState.block));
        if (deltaBlocks > 0 && borrowSpeed > 0) {
            uint borrowAmount = div_(PToken(pToken).totalBorrows(), marketBorrowIndex);
            uint wpcAccrued = mul_(deltaBlocks, borrowSpeed);
            Double memory ratio = borrowAmount > 0 ? fraction(wpcAccrued, borrowAmount) : Double({mantissa : 0});
            Double memory index = add_(Double({mantissa : borrowState.index}), ratio);
            wpcBorrowState[pToken] = WpcMarketState({
            index : safe224(index.mantissa, "new index exceeds 224 bits"),
            block : safe32(blockNumber, "block number exceeds 32 bits")
            });
        } else if (deltaBlocks > 0) {
            borrowState.block = safe32(blockNumber, "block number exceeds 32 bits");
        }
    }

    /**
     * @notice Calculate WPC accrued by a supplier and possibly transfer it to them
     * @param pToken The market in which the supplier is interacting
     * @param supplier The address of the supplier to distribute WPC to
     */
    function distributeSupplierWpc(address pToken, address supplier, bool distributeAll) internal {
        WpcMarketState storage supplyState = wpcSupplyState[pToken];
        Double memory supplyIndex = Double({mantissa : supplyState.index});
        Double memory supplierIndex = Double({mantissa : wpcSupplierIndex[pToken][supplier]});
        wpcSupplierIndex[pToken][supplier] = supplyIndex.mantissa;

        if (supplierIndex.mantissa == 0 && supplyIndex.mantissa > 0) {
            supplierIndex.mantissa = wpcInitialIndex;
        }

        Double memory deltaIndex = sub_(supplyIndex, supplierIndex);
        uint supplierTokens = PToken(pToken).balanceOf(supplier);
        uint supplierDelta = mul_(supplierTokens, deltaIndex);
        uint supplierAccrued = add_(wpcAccrued[supplier], supplierDelta);
        wpcAccrued[supplier] = grantWpcInternal(supplier, supplierAccrued, distributeAll ? 0 : wpcClaimThreshold);
        emit DistributedSupplierWpc(PToken(pToken), supplier, supplierDelta, supplyIndex.mantissa);
    }


    /**
     * @notice Calculate WPC accrued by a borrower and possibly transfer it to them
     * @dev Borrowers will not begin to accrue until after the first interaction with the protocol.
     * @param pToken The market in which the borrower is interacting
     * @param borrower The address of the borrower to distribute WPC to
     */
    function distributeBorrowerWpc(address pToken, address borrower, Exp memory marketBorrowIndex, bool distributeAll) internal {
        WpcMarketState storage borrowState = wpcBorrowState[pToken];
        Double memory borrowIndex = Double({mantissa : borrowState.index});
        Double memory borrowerIndex = Double({mantissa : wpcBorrowerIndex[pToken][borrower]});
        wpcBorrowerIndex[pToken][borrower] = borrowIndex.mantissa;

        if (borrowerIndex.mantissa > 0) {
            Double memory deltaIndex = sub_(borrowIndex, borrowerIndex);
            uint borrowerAmount = div_(PToken(pToken).borrowBalanceStored(borrower), marketBorrowIndex);
            uint borrowerDelta = mul_(borrowerAmount, deltaIndex);
            uint borrowerAccrued = add_(wpcAccrued[borrower], borrowerDelta);
            wpcAccrued[borrower] = grantWpcInternal(borrower, borrowerAccrued, distributeAll ? 0 : wpcClaimThreshold);
            emit DistributedBorrowerWpc(PToken(pToken), borrower, borrowerDelta, borrowIndex.mantissa);
        }
    }


    /**
     * @notice Transfer WPC to the user, if they are above the threshold
     * @dev Note: If there is not enough WPC, we do not perform the transfer all.
     * @param user The address of the user to transfer WPC to
     * @param userAccrued The amount of WPC to (possibly) transfer
     * @return The amount of WPC which was NOT transferred to the user
     */
    function grantWpcInternal(address user, uint userAccrued, uint threshold) internal returns (uint) {
        if (userAccrued >= threshold && userAccrued > 0) {
            if (enableWpcClaim) {
                uint _amountSend = mul_(userAccrued, 1000);
                bytes memory payload = abi.encodeWithSignature("mint(address,uint256)", user, _amountSend);
                (bool success, bytes memory returnData) = address(piggy).call(payload);
                require(success);
                return 0;
            }
        }
        return userAccrued;
    }

    /**
     * @notice Claim all the wpc accrued by holder in all markets
     * @param holder The address to claim WPC for
     */
    function claimWpc(address holder) public {
        claimWpc(holder, comptroller.getAllMarkets());
    }

    /**
     * @notice Claim all the comp accrued by holder in the specified markets
     * @param holder The address to claim WPC for
     * @param pTokens The list of markets to claim WPC in
     */
    function claimWpc(address holder, PToken[] memory pTokens) public {
        address[] memory holders = new address[](1);
        holders[0] = holder;
        claimWpc(holders, pTokens, true, true);
    }

    /**
     * @notice Claim all wpc accrued by the holders
     * @param holders The addresses to claim WPC for
     * @param pTokens The list of markets to claim WPC in
     * @param borrowers Whether or not to claim WPC earned by borrowing
     * @param suppliers Whether or not to claim WPC earned by supplying
     */
    function claimWpc(address[] memory holders, PToken[] memory pTokens, bool borrowers, bool suppliers) public {
        require(enableWpcClaim, "Claim is not enabled");

        for (uint i = 0; i < pTokens.length; i++) {
            PToken pToken = pTokens[i];
            require(comptroller.isMarketListed(address(pToken)), "market must be listed");
            if (borrowers == true) {
                Exp memory borrowIndex = Exp({mantissa : pToken.borrowIndex()});
                updateWpcBorrowIndex(address(pToken), borrowIndex);
                for (uint j = 0; j < holders.length; j++) {
                    distributeBorrowerWpc(address(pToken), holders[j], borrowIndex, true);
                }
            }
            if (suppliers == true) {
                updateWpcSupplyIndex(address(pToken));
                for (uint j = 0; j < holders.length; j++) {
                    distributeSupplierWpc(address(pToken), holders[j], true);
                }
            }
        }

    }

    /*** WPC Distribution Admin ***/

    function _setWpcSpeed(PToken pToken, uint wpcSpeed) public onlyOwner {
        setWpcSpeedInternal(pToken, wpcSpeed);
    }

    function _setEnableWpcClaim(bool state) public onlyOwner {
        enableWpcClaim = state;
        emit EnableState("enableWpcClaim", state);
    }

    function _setEnableDistributeMintWpc(bool state) public onlyOwner {
        enableDistributeMintWpc = state;
        emit EnableState("enableDistributeMintWpc", state);
    }

    function _setEnableDistributeRedeemWpc(bool state) public onlyOwner {
        enableDistributeRedeemWpc = state;
        emit EnableState("enableDistributeRedeemWpc", state);
    }

    function _setEnableDistributeBorrowWpc(bool state) public onlyOwner {
        enableDistributeBorrowWpc = state;
        emit EnableState("enableDistributeBorrowWpc", state);
    }

    function _setEnableDistributeRepayBorrowWpc(bool state) public onlyOwner {
        enableDistributeRepayBorrowWpc = state;
        emit EnableState("enableDistributeRepayBorrowWpc", state);
    }

    function _setEnableDistributeSeizeWpc(bool state) public onlyOwner {
        enableDistributeSeizeWpc = state;
        emit EnableState("enableDistributeSeizeWpc", state);
    }

    function _setEnableDistributeTransferWpc(bool state) public onlyOwner {
        enableDistributeTransferWpc = state;
        emit EnableState("enableDistributeTransferWpc", state);
    }

    function _setEnableAll(bool state) public onlyOwner {
        _setEnableDistributeMintWpc(state);
        _setEnableDistributeRedeemWpc(state);
        _setEnableDistributeBorrowWpc(state);
        _setEnableDistributeRepayBorrowWpc(state);
        _setEnableDistributeSeizeWpc(state);
        _setEnableDistributeTransferWpc(state);
        _setEnableWpcClaim(state);
    }

    function _transferWpc(address to, uint amount) public onlyOwner {
        _transferToken(address(piggy), to, amount);
    }

    function _transferToken(address token, address to, uint amount) public onlyOwner {
        IERC20 erc20 = IERC20(token);

        uint balance = erc20.balanceOf(address(this));
        if (balance < amount) {
            amount = balance;
        }

        erc20.transfer(to, amount);
    }

    function pendingWpcAccrued(address holder, bool borrowers, bool suppliers) public view returns (uint256){
        return pendingWpcInternal(holder, borrowers, suppliers);
    }

    function pendingWpcInternal(address holder, bool borrowers, bool suppliers) internal view returns (uint256){

        uint256 pendingWpc = wpcAccrued[holder];

        PToken[] memory pTokens = comptroller.getAllMarkets();
        for (uint i = 0; i < pTokens.length; i++) {
            address pToken = address(pTokens[i]);
            uint tmp = 0;
            if (borrowers == true) {
                tmp = pendingWpcBorrowInternal(holder, pToken);
                pendingWpc = add_(pendingWpc, tmp);
            }
            if (suppliers == true) {
                tmp = pendingWpcSupplyInternal(holder, pToken);
                pendingWpc = add_(pendingWpc, tmp);
            }
        }

        return pendingWpc;
    }

    function pendingWpcBorrowInternal(address borrower, address pToken) internal view returns (uint256){
        if (enableDistributeBorrowWpc && enableDistributeRepayBorrowWpc) {
            Exp memory marketBorrowIndex = Exp({mantissa : PToken(pToken).borrowIndex()});
            WpcMarketState memory borrowState = pendingWpcBorrowIndex(pToken, marketBorrowIndex);

            Double memory borrowIndex = Double({mantissa : borrowState.index});
            Double memory borrowerIndex = Double({mantissa : wpcBorrowerIndex[pToken][borrower]});
            if (borrowerIndex.mantissa > 0) {
                Double memory deltaIndex = sub_(borrowIndex, borrowerIndex);
                uint borrowerAmount = div_(PToken(pToken).borrowBalanceStored(borrower), marketBorrowIndex);
                uint borrowerDelta = mul_(borrowerAmount, deltaIndex);
                return borrowerDelta;
            }
        }
        return 0;
    }

    function pendingWpcBorrowIndex(address pToken, Exp memory marketBorrowIndex) internal view returns (WpcMarketState memory){
        WpcMarketState memory borrowState = wpcBorrowState[pToken];
        uint borrowSpeed = wpcSpeeds[pToken];
        uint blockNumber = block.number;
        uint deltaBlocks = sub_(blockNumber, uint(borrowState.block));
        if (deltaBlocks > 0 && borrowSpeed > 0) {
            uint borrowAmount = div_(PToken(pToken).totalBorrows(), marketBorrowIndex);
            uint wpcAccrued = mul_(deltaBlocks, borrowSpeed);
            Double memory ratio = borrowAmount > 0 ? fraction(wpcAccrued, borrowAmount) : Double({mantissa : 0});
            Double memory index = add_(Double({mantissa : borrowState.index}), ratio);
            borrowState = WpcMarketState({
            index : safe224(index.mantissa, "new index exceeds 224 bits"),
            block : safe32(blockNumber, "block number exceeds 32 bits")
            });
        } else if (deltaBlocks > 0) {
            borrowState = WpcMarketState({
            index : borrowState.index,
            block : safe32(blockNumber, "block number exceeds 32 bits")
            });
        }
        return borrowState;
    }

    function pendingWpcSupplyInternal(address supplier, address pToken) internal view returns (uint256){
        if (enableDistributeMintWpc && enableDistributeRedeemWpc) {
            WpcMarketState memory supplyState = pendingWpcSupplyIndex(pToken);
            Double memory supplyIndex = Double({mantissa : supplyState.index});
            Double memory supplierIndex = Double({mantissa : wpcSupplierIndex[pToken][supplier]});
            if (supplierIndex.mantissa == 0 && supplyIndex.mantissa > 0) {
                supplierIndex.mantissa = wpcInitialIndex;
            }
            Double memory deltaIndex = sub_(supplyIndex, supplierIndex);
            uint supplierTokens = PToken(pToken).balanceOf(supplier);
            uint supplierDelta = mul_(supplierTokens, deltaIndex);
            return supplierDelta;
        }
        return 0;
    }

    function pendingWpcSupplyIndex(address pToken) internal view returns (WpcMarketState memory){
        WpcMarketState memory supplyState = wpcSupplyState[pToken];
        uint supplySpeed = wpcSpeeds[pToken];
        uint blockNumber = block.number;
        uint deltaBlocks = sub_(blockNumber, uint(supplyState.block));

        if (deltaBlocks > 0 && supplySpeed > 0) {
            uint supplyTokens = PToken(pToken).totalSupply();
            uint wpcAccrued = mul_(deltaBlocks, supplySpeed);
            Double memory ratio = supplyTokens > 0 ? fraction(wpcAccrued, supplyTokens) : Double({mantissa : 0});
            Double memory index = add_(Double({mantissa : supplyState.index}), ratio);
            supplyState = WpcMarketState({
            index : safe224(index.mantissa, "new index exceeds 224 bits"),
            block : safe32(blockNumber, "block number exceeds 32 bits")
            });
        } else if (deltaBlocks > 0) {
            supplyState = WpcMarketState({
            index : supplyState.index,
            block : safe32(blockNumber, "block number exceeds 32 bits")
            });
        }
        return supplyState;
    }

    function _setPiggy(address _piggy) public onlyOwner {
        piggy = IERC20(_piggy);
    }

}
