pragma solidity 0.6.12;

import "./PEther.sol";

/**
 * @title Compound's Maximillion Contract
 * @author Compound
 */
contract Maximillion {
    /**
     * @notice The default cEther market to repay in
     */
    PEther public pEther;

    /**
     * @notice Construct a Maximillion to repay max in a CEther market
     */
    constructor(PEther pEther_) public {
        pEther = pEther_;
    }

    /**
     * @notice msg.sender sends Ether to repay an account's borrow in the cEther market
     * @dev The provided Ether is applied towards the borrow balance, any excess is refunded
     * @param borrower The address of the borrower account to repay on behalf of
     */
    function repayBehalf(address borrower) public payable {
        repayBehalfExplicit(borrower, pEther);
    }

    /**
     * @notice msg.sender sends Ether to repay an account's borrow in a cEther market
     * @dev The provided Ether is applied towards the borrow balance, any excess is refunded
     * @param borrower The address of the borrower account to repay on behalf of
     * @param pEther_ The address of the cEther contract to repay in
     */
    function repayBehalfExplicit(address borrower, PEther pEther_) public payable {
        uint received = msg.value;
        uint borrows = pEther_.borrowBalanceCurrent(borrower);
        if (received > borrows) {
            pEther_.repayBorrowBehalf.value(borrows)(borrower);
            msg.sender.transfer(received - borrows);
        } else {
            pEther_.repayBorrowBehalf.value(received)(borrower);
        }
    }
}
