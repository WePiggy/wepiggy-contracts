pragma solidity ^0.6.0;

import "./IFlashLoanReceiver.sol";
import "./IFlashloan.sol";
import "../token/IPToken.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";

contract Flashloan is IFlashloan, OwnableUpgradeSafe {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public constant ethAddress = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    mapping(address => bool) public activeCaller;
    mapping(address => bool) public activeReceiver;

    event FlashLoan(address _receiver, address _reserve, uint256 _amount, uint256 amountFee, uint256 timestamp);
    event Action(string action, address[] addresses);

    function initialize() public initializer {
        super.__Ownable_init();
    }

    function registerActiveCaller(address[] memory callers) public onlyOwner {
        for (uint i = 0; i < callers.length; i++) {
            address caller = callers[i];
            activeCaller[caller] = true;
        }
        emit Action("registerActiveCaller", callers);
    }

    function unRegisterActiveCaller(address[] memory callers) public onlyOwner {
        for (uint i = 0; i < callers.length; i++) {
            address caller = callers[i];
            activeCaller[caller] = false;
        }
        emit Action("unRegisterActiveCaller", callers);
    }

    function registerActiveReceiver(address[] memory receivers) public onlyOwner {
        for (uint i = 0; i < receivers.length; i++) {
            address receiver = receivers[i];
            activeReceiver[receiver] = true;
        }
        emit Action("registerActiveReceiver", receivers);
    }

    function unRegisterActiveReceiver(address[] memory receivers) public onlyOwner {
        for (uint i = 0; i < receivers.length; i++) {
            address receiver = receivers[i];
            activeReceiver[receiver] = false;
        }
        emit Action("unRegisterActiveReceiver", receivers);
    }

    function transfer(address payable _destination, address _reserve, uint256 _amount) public onlyOwner {
        transferInternal(_destination, _reserve, _amount);
    }

    function flashloan(address _pToken, address _receiver, address _reserve, uint256 _amount, bytes memory _params) external override {

        address payable caller = msg.sender;
        require(activeCaller[caller], "Action require an active caller");
        require(_amount > 0, "amount must bigger than zero");
        require(activeReceiver[_receiver], "require an active receiver");

        uint256 availableLiquidityBefore = getBalanceInternal(address(this), _reserve);
        require(availableLiquidityBefore >= _amount, "There is not enough liquidity available to borrow");

        uint256 amountFee = getAmountFee(_reserve, _amount);

        //get the FlashLoanReceiver instance
        IFlashLoanReceiver receiver = IFlashLoanReceiver(_receiver);

        address payable userPayable = address(uint160(_receiver));

        transferInternal(userPayable, _reserve, _amount);

        //execute action of the receiver
        receiver.executeOperation(_reserve, _amount, amountFee, _params);

        //check that the actual balance of the core contract includes the returned amount
        uint availableLiquidityAfter = getBalanceInternal(address(this), _reserve);
        uint difference = availableLiquidityAfter.sub(availableLiquidityBefore);
        require(difference >= amountFee, "The actual balance of the protocol is inconsistent");

        transferInternal(caller, _reserve, _amount);

        IPToken pToken = IPToken(_pToken);
        updateStateOnFlashLoan(pToken, _reserve, availableLiquidityBefore, amountFee);

        emit FlashLoan(_receiver, _reserve, _amount, amountFee, block.timestamp);

    }

    function getAmountFee(address _reserve, uint256 _amount) internal returns (uint256){
        return 0;
    }

    function updateStateOnFlashLoan(IPToken pToken, address _reserve, uint256 availableLiquidityBefore, uint256 amountFee) internal {
    }

    function transferInternal(address payable _destination, address _reserve, uint256 _amount) internal {
        if (_reserve == ethAddress) {
            _destination.transfer(_amount);
            return;
        }
        IERC20(_reserve).safeTransfer(_destination, _amount);
    }

    function getBalanceInternal(address _target, address _reserve) internal view returns (uint256) {
        if (_reserve == ethAddress) {
            return _target.balance;
        }
        return IERC20(_reserve).balanceOf(_target);
    }

    receive() external payable {
    }


}
