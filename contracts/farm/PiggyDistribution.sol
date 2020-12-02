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

    /// @notice The rate at which the flywheel distributes WPC, per block
    uint public wpcRate;

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

    /// @notice Emitted when market comped status is changed
    event MarketWpcMinted(PToken pToken, bool isMinted);

    /// @notice Emitted when WPC rate is changed
    event NewWpcRate(uint oldWpcRate, uint newWpcRate);

    /// @notice Emitted when a new WPC speed is calculated for a market
    event WpcSpeedUpdated(PToken indexed pToken, uint newSpeed);

    /// @notice Emitted when WPC is distributed to a supplier
    event DistributedSupplierWpc(PToken indexed pToken, address indexed supplier, uint wpcDelta, uint wpcSupplyIndex);

    /// @notice Emitted when WPC is distributed to a borrower
    event DistributedBorrowerWpc(PToken indexed pToken, address indexed borrower, uint wpcDelta, uint wpcBorrowIndex);

    event StakeTokenToPiggyBreeder(IERC20 token, uint pid, uint amount);

    event ClaimWpcFromPiggyBreeder(uint pid);

    function initialize(IERC20 _piggy, IPiggyBreeder _piggyBreeder, Comptroller _comptroller) public initializer {

        piggy = _piggy;
        piggyBreeder = _piggyBreeder;
        comptroller = _comptroller;

        super.__Ownable_init();
    }


    function distributeMintWpc(address pToken, address minter, bool distributeAll) public override(IPiggyDistribution) {

        require(msg.sender == address(comptroller) || msg.sender == owner(), "only comptroller or owner");

        //        updateWpcSupplyIndex(pToken);
        //        distributeSupplierWpc(pToken, minter, distributeAll);

    }

    function distributeRedeemWpc(address pToken, address redeemer, bool distributeAll) public override(IPiggyDistribution) {
        require(msg.sender == address(comptroller) || msg.sender == owner(), "only comptroller or owner");
        //        updateWpcSupplyIndex(cToken);
        //        distributeSupplierWpc(cToken, redeemer, false);
    }

    function distributeBorrowWpc(address pToken, address borrower, bool distributeAll) public override(IPiggyDistribution) {

        require(msg.sender == address(comptroller) || msg.sender == owner(), "only comptroller or owner");

        Exp memory borrowIndex = Exp({mantissa : PToken(pToken).borrowIndex()});
        updateWpcBorrowIndex(pToken, borrowIndex);
        distributeBorrowerWpc(pToken, borrower, borrowIndex, distributeAll);

    }

    function distributeRepayBorrowWpc(address pToken, address borrower, bool distributeAll) public override(IPiggyDistribution) {

        require(msg.sender == address(comptroller) || msg.sender == owner(), "only comptroller or owner");

        Exp memory borrowIndex = Exp({mantissa : PToken(pToken).borrowIndex()});
        updateWpcBorrowIndex(pToken, borrowIndex);
        distributeBorrowerWpc(pToken, borrower, borrowIndex, distributeAll);
    }

    function distributeSeizeWpc(address pTokenCollateral, address borrower, address liquidator, bool distributeAll) public override(IPiggyDistribution) {

        require(msg.sender == address(comptroller) || msg.sender == owner(), "only comptroller or owner");

        updateWpcSupplyIndex(pTokenCollateral);
        distributeSupplierWpc(pTokenCollateral, borrower, distributeAll);
        distributeSupplierWpc(pTokenCollateral, liquidator, distributeAll);
    }

    function distributeTransferWpc(address pToken, address src, address dst, bool distributeAll) public override(IPiggyDistribution) {

        require(msg.sender == address(comptroller) || msg.sender == owner(), "only comptroller or owner");

        updateWpcSupplyIndex(pToken);
        distributeSupplierWpc(pToken, src, distributeAll);
        distributeSupplierWpc(pToken, dst, distributeAll);
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

    /**
    * @notice Recalculate and update WPC speeds for all WPC markets
    */
    function _refreshWpcSpeeds() public onlyOwner {
        refreshWpcSpeedsInternal();
    }

    function refreshWpcSpeedsInternal() internal {

        PToken[] memory allMarkets_ = comptroller.getAllMarkets();

        for (uint i = 0; i < allMarkets_.length; i++) {
            PToken pToken = allMarkets_[i];
            Exp memory borrowIndex = Exp({mantissa : pToken.borrowIndex()});
            updateWpcSupplyIndex(address(pToken));
            updateWpcBorrowIndex(address(pToken), borrowIndex);
        }

        Exp memory totalUtility = Exp({mantissa : 0});
        Exp[] memory utilities = new Exp[](allMarkets_.length);
        for (uint i = 0; i < allMarkets_.length; i++) {
            PToken pToken = allMarkets_[i];
            if (comptroller.isMarketMinted(address(pToken))) {
                uint assetPriceMantissa = comptroller.oracle().getUnderlyingPrice(pToken);
                Exp memory assetPrice = Exp({mantissa : assetPriceMantissa});
                Exp memory utility = mul_(assetPrice, pToken.totalBorrows());
                utilities[i] = utility;
                totalUtility = add_(totalUtility, utility);
            }
        }

        for (uint i = 0; i < allMarkets_.length; i++) {
            PToken pToken = comptroller.getAllMarkets()[i];
            uint newSpeed = totalUtility.mantissa > 0 ? mul_(wpcRate, div_(utilities[i], totalUtility)) : 0;
            wpcSpeeds[address(pToken)] = newSpeed;
            emit WpcSpeedUpdated(pToken, newSpeed);
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
        wpcAccrued[supplier] = transferWpc(supplier, supplierAccrued, distributeAll ? 0 : wpcClaimThreshold);
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
            wpcAccrued[borrower] = transferWpc(borrower, borrowerAccrued, distributeAll ? 0 : wpcClaimThreshold);
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
    function transferWpc(address user, uint userAccrued, uint threshold) internal returns (uint) {
        if (userAccrued >= threshold && userAccrued > 0) {
            uint wpcRemaining = piggy.balanceOf(address(this));
            if (userAccrued <= wpcRemaining) {
                piggy.transfer(user, userAccrued);
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
        return claimWpc(holder, comptroller.getAllMarkets());
    }

    /**
     * @notice Claim all the comp accrued by holder in the specified markets
     * @param holder The address to claim WPC for
     * @param pTokens The list of markets to claim WPC in
     */
    function claimWpc(address holder, PToken[] memory pTokens) public {
        address[] memory holders = new address[](1);
        holders[0] = holder;
        claimWpc(holders, pTokens, true, false);
    }

    /**
     * @notice Claim all wpc accrued by the holders
     * @param holders The addresses to claim WPC for
     * @param pTokens The list of markets to claim WPC in
     * @param borrowers Whether or not to claim WPC earned by borrowing
     * @param suppliers Whether or not to claim WPC earned by supplying
     */
    function claimWpc(address[] memory holders, PToken[] memory pTokens, bool borrowers, bool suppliers) public {
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

    /**
     * @notice Set the amount of WPC distributed per block
     * @param wpcRate_ The amount of WPC wei per block to distribute
     */
    function _setWpcRate(uint wpcRate_) public onlyOwner {
        uint oldRate = wpcRate;

        wpcRate = wpcRate_;
        emit NewWpcRate(oldRate, wpcRate_);

        refreshWpcSpeedsInternal();
    }

    /**
     * @notice Add markets to wpcMarkets, allowing them to earn WPC in the flywheel
     * @param pTokens The addresses of the markets to add
     */
    function _addWpcMarkets(address[] memory pTokens) public onlyOwner {

        for (uint i = 0; i < pTokens.length; i++) {
            _addWpcMarketInternal(pTokens[i]);
        }

        refreshWpcSpeedsInternal();
    }

    function _addWpcMarketInternal(address pToken) internal {

        require(comptroller.isMarketListed(pToken), "wpc market is not listed");
        require(comptroller.isMarketMinted(pToken) == false, "wpc market already added");

        comptroller._setMarketMinted(pToken, true);

        emit MarketWpcMinted(PToken(pToken), true);

        if (wpcSupplyState[pToken].index == 0 && wpcSupplyState[pToken].block == 0) {
            wpcSupplyState[pToken] = WpcMarketState({
            index : wpcInitialIndex,
            block : safe32(block.number, "block number exceeds 32 bits")
            });
        }

        if (wpcBorrowState[pToken].index == 0 && wpcBorrowState[pToken].block == 0) {
            wpcBorrowState[pToken] = WpcMarketState({
            index : wpcInitialIndex,
            block : safe32(block.number, "block number exceeds 32 bits")
            });
        }
    }

    /**
     * @notice Remove a market from compMarkets, preventing it from earning WPC in the flywheel
     * @param pToken The address of the market to drop
     */
    function _dropWpcMarket(address pToken) public onlyOwner {

        require(comptroller.isMarketMinted(pToken), "market is not a wpc market");

        comptroller._setMarketMinted(pToken, false);
        emit MarketWpcMinted(PToken(pToken), false);

        refreshWpcSpeedsInternal();
    }

    function transferALLWPC(address to) public onlyOwner {
        piggy.transfer(to, piggy.balanceOf(address(this)));
    }

}