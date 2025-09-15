// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";
contract FundMeTest is Test {
    FundMe fundMe;
    address USER = makeAddr("user");
    uint256 constant SEND_VALUE = 0.1 ether;
    uint256 constant GAS_PRICE = 1;
    function setUp() external {
        // fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
    }
    function testMinumDollarIsFive() public {
        assertEq(fundMe.MINIMUM_USD(), 5 * 10 ** 18);
    }
    function testOwnerIsMsgSender() public {
        assertEq(fundMe.getOwner(), msg.sender);
    }
    function testPriceFeedVersionIsAccurate() public {
        assertEq(fundMe.getVersion(), 4);
    }
    function testFundFailsWithoutEnoughEth() public {
        vm.expectRevert();
        fundMe.fund();
    }
    modifier funded() {
        vm.deal(USER, 1 ether);
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }
    function testFundUpdatesFundedDataStructure() public {
        vm.deal(USER, 1 ether);
        vm.prank(USER); //THE NEXT TXN WILL BE SENT BY USER
        fundMe.fund{value: SEND_VALUE}();
        assertEq(fundMe.getaddressToAmountFunded(USER), SEND_VALUE);
    }
    function testAddsFunderToArrayOfFunders() public {
        vm.deal(USER, 1 ether);
        vm.prank(USER); //THE NEXT TXN WILL BE SENT BY USER
        fundMe.fund{value: SEND_VALUE}();
        assertEq(fundMe.getFunder(0), USER);
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.expectRevert();
        fundMe.withdraw();
    }
    function testWithdrawWithASingleFunder() public funded {
        //Arrange
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;
        //Act
        uint256 gasStart = gasleft();
        // (bool success, ) = address(fundMe).call{value: address(fundMe).balance}(""){};
        vm.txGasPrice(GAS_PRICE);
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();
        uint256 gasEnd = gasleft();
        uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice;
        console.log("Gas Used:", gasUsed);
        //Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(
            startingFundMeBalance + startingOwnerBalance,
            endingOwnerBalance
        );
    }   
  function testWithdrawFromMultipleFunders() public funded {
    // Arrange
    uint160 numberOfFunders = 10;
    uint256 startingOwnerBalance = fundMe.getOwner().balance;
    uint256 startingFundMeBalance = address(fundMe).balance;

    for (uint160 i = 1; i < numberOfFunders; i++) {
        address funder = address(i);
        vm.deal(funder, SEND_VALUE);
        vm.prank(funder);
        fundMe.fund{value: SEND_VALUE}();
    }

    // Act
    vm.prank(fundMe.getOwner());
    fundMe.withdraw();

    // Assert
    uint256 endingOwnerBalance = fundMe.getOwner().balance;
    uint256 endingFundMeBalance = address(fundMe).balance;

    assertEq(endingFundMeBalance, 0);
    assertEq(
        startingOwnerBalance + startingFundMeBalance + (numberOfFunders - 1) * SEND_VALUE,
        endingOwnerBalance
    );
}

}
