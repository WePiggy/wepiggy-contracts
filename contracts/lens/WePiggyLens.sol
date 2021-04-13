pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../oracle/IPriceOracle.sol";
import "../token/ERC20Interface.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

interface ComptrollerLensInterface {
    function markets(address) external view returns (bool, uint);

    function oracle() external view returns (IPriceOracle);

    function getAccountLiquidity(address) external view returns (uint, uint, uint);

    function getAssetsIn(address) external view returns (PTokenLensInterface[] memory);
}

interface PTokenLensInterface {
    function exchangeRateStored() external view returns (uint256);

    function comptroller() external view returns (address);

    function supplyRatePerBlock() external view returns (uint256);

    function borrowRatePerBlock() external view returns (uint256);

    function reserveFactorMantissa() external view returns (uint256);

    function totalBorrows() external view returns (uint256);

    function totalReserves() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function getCash() external view returns (uint256);

    function underlying() external view returns (address);

    function decimals() external view returns (uint8);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function allowance(address owner, address spender) external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function getAccountSnapshot(address account) external virtual view returns (uint256, uint256, uint256, uint256);
}

interface PiggyDistributionLensInterface {
    function pendingWpcAccrued(address holder, bool borrowers, bool suppliers) external view returns (uint256);
}


interface PiggyBreederLensInterface {
    function pendingPiggy(uint256 _pid, address _user) external view returns (uint256);
}

contract WePiggyLens {

    using SafeMath for uint256;

    struct PTokenMetadata {
        address pToken;
        uint exchangeRateCurrent;
        uint supplyRatePerBlock;
        uint borrowRatePerBlock;
        uint reserveFactorMantissa;
        uint totalBorrows;
        uint totalReserves;
        uint totalSupply;
        uint totalCash;
        bool isListed;
        uint collateralFactorMantissa;
        address underlyingAssetAddress;
        uint pTokenDecimals;
        uint underlyingDecimals;
    }

    function pTokenMetadata(PTokenLensInterface pToken) public view returns (PTokenMetadata memory){

        uint exchangeRateCurrent = pToken.exchangeRateStored();
        ComptrollerLensInterface comptroller = ComptrollerLensInterface(pToken.comptroller());
        (bool isListed, uint collateralFactorMantissa) = comptroller.markets(address(pToken));

        address underlyingAssetAddress;
        uint underlyingDecimals;

        if (compareStrings(pToken.symbol(), "pETH")) {
            underlyingAssetAddress = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
            underlyingDecimals = 18;
        } else {
            PTokenLensInterface pErc20 = PTokenLensInterface(address(pToken));
            underlyingAssetAddress = pErc20.underlying();
            underlyingDecimals = IEIP20(pErc20.underlying()).decimals();
        }

        return PTokenMetadata({
        pToken : address(pToken),
        exchangeRateCurrent : exchangeRateCurrent,
        supplyRatePerBlock : pToken.supplyRatePerBlock(),
        borrowRatePerBlock : pToken.borrowRatePerBlock(),
        reserveFactorMantissa : pToken.reserveFactorMantissa(),
        totalBorrows : pToken.totalBorrows(),
        totalReserves : pToken.totalReserves(),
        totalSupply : pToken.totalSupply(),
        totalCash : pToken.getCash(),
        isListed : isListed,
        collateralFactorMantissa : collateralFactorMantissa,
        underlyingAssetAddress : underlyingAssetAddress,
        pTokenDecimals : pToken.decimals(),
        underlyingDecimals : underlyingDecimals
        });
    }

    function pTokenMetadataAll(PTokenLensInterface[] calldata pTokens) public view returns (PTokenMetadata[] memory) {
        uint pTokenCount = pTokens.length;
        PTokenMetadata[] memory res = new PTokenMetadata[](pTokenCount);
        for (uint i = 0; i < pTokenCount; i++) {
            res[i] = pTokenMetadata(pTokens[i]);
        }
        return res;
    }

    struct PTokenBalances {
        address pToken;
        uint balance;
        uint borrowBalance; //用户的借款
        uint exchangeRateMantissa;
    }

    function pTokenBalances(PTokenLensInterface pToken, address payable account) public view returns (PTokenBalances memory) {

        (,uint tokenBalance,uint borrowBalance,uint exchangeRateMantissa) = pToken.getAccountSnapshot(account);

        return PTokenBalances({
        pToken : address(pToken),
        balance : tokenBalance,
        borrowBalance : borrowBalance,
        exchangeRateMantissa : exchangeRateMantissa
        });

    }

    function pTokenBalancesAll(PTokenLensInterface[] calldata pTokens, address payable account) public view returns (PTokenBalances[] memory) {
        uint pTokenCount = pTokens.length;
        PTokenBalances[] memory res = new PTokenBalances[](pTokenCount);
        for (uint i = 0; i < pTokenCount; i++) {
            res[i] = pTokenBalances(pTokens[i], account);
        }
        return res;
    }

    struct AccountLimits {
        PTokenLensInterface[] markets;
        uint liquidity;
        uint shortfall;
    }


    function getAccountLimits(ComptrollerLensInterface comptroller, address account) public view returns (AccountLimits memory) {
        (uint errorCode, uint liquidity, uint shortfall) = comptroller.getAccountLiquidity(account);
        require(errorCode == 0);

        return AccountLimits({
        markets : comptroller.getAssetsIn(account),
        liquidity : liquidity,
        shortfall : shortfall
        });
    }


    function pendingWpcAccrued(PiggyDistributionLensInterface piggyDistribution, address account, bool borrowers, bool suppliers) public view returns (uint256){
        return piggyDistribution.pendingWpcAccrued(account, borrowers, suppliers);
    }

    function pendingPiggy(PiggyBreederLensInterface piggyBreeder, address _user, uint256 _pid) public view returns (uint256){
        return piggyBreeder.pendingPiggy(_pid, _user);
    }

    function pendingPiggyAll(PiggyBreederLensInterface piggyBreeder, address _user, uint256[] calldata _pids) public view returns (uint256[] memory){
        uint count = _pids.length;
        uint256[] memory res = new uint256[](count);
        for (uint i = 0; i < count; i++) {
            res[i] = pendingPiggy(piggyBreeder, _user, _pids[i]);
        }
        return res;
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }
}
