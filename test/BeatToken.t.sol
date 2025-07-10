// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {BeatToken} from "../src/BeatToken.sol";

contract BeatTokenTest is Test {
    BeatToken public beatToken;
    
    address public owner;
    address public festivalContract;
    address public user;
    
    function setUp() public {
        owner = address(this); // Test contract is the owner
        festivalContract = makeAddr("festivalContract");
        user = makeAddr("user");
        
        beatToken = new BeatToken();
    }
    
    function test_SetFestivalContract_AfterOwnershipTransfer() public {
        address newOwner = makeAddr("newOwner");
        
        // Transfer ownership
        beatToken.transferOwnership(newOwner);
        
        // New owner accepts
        vm.prank(newOwner);
        beatToken.acceptOwnership();
        
        // Old owner can no longer set festival contract
        vm.expectRevert();
        beatToken.setFestivalContract(festivalContract);
        
        // New owner can set it
        vm.prank(newOwner);
        beatToken.setFestivalContract(festivalContract);
        assertEq(beatToken.festivalContract(), festivalContract);
    }
    
    
    function testFuzz_SetFestivalContract_CannotOverwrite(
        address _first,
        address _second
    ) public {
        vm.assume(_first != address(0));
        vm.assume(_second != address(0));
        vm.assume(_first != _second);
        
        // Set first
        beatToken.setFestivalContract(_first);
        
        // Try to overwrite
        vm.expectRevert("Festival contract already set");
        beatToken.setFestivalContract(_second);
        
        // Verify first is still set correctly
        assertEq(beatToken.festivalContract(), _first);
    }


}