pragma solidity 0.6.12;

import "../flashloan/IFlashLoanReceiver.sol";
import "../token/PERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";

contract MockMintFlashLoanReceiver is IFlashLoanReceiver {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public constant ethAddress = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    event Msg(address _reserve, uint256 _amount, uint256 _fee, bytes _params);

    function executeOperation(address _reserve, uint256 _amount, uint256 _fee, bytes calldata _params) external override {

        uint amount = _amount.add(_fee);

        address sender = msg.sender;
        IERC20 erc20 = IERC20(_reserve);

        address pUsdt = address(0x34ab3D31e47df3250c742B39F3790c823B9627F2);
        erc20.safeApprove(pUsdt, amount);

        PERC20 pErc20 = PERC20(pUsdt);
        pErc20.mint(amount);

        erc20.safeTransfer(sender, amount);

        emit Msg(_reserve, _amount, _fee, _params);

    }

    function transfer(address payable _destination, address _reserve, uint256 _amount) public {
        if (_reserve == ethAddress) {
            _destination.transfer(_amount);
            return;
        }
        IERC20(_reserve).safeTransfer(_destination, _amount);
    }


}
