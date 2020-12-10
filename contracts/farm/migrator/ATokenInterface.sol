pragma solidity 0.6.12;

interface ATokenInterface {

    function transfer(address dst, uint amount) external returns (bool);

    function transferFrom(address src, address dst, uint amount) external returns (bool);

    function approve(address spender, uint amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint);

    function balanceOf(address owner) external view returns (uint);

    function redeem(uint256 _amount) external;

    function underlyingAssetAddress() external view returns (address);
}