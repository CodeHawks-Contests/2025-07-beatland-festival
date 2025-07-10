// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {FestivalPass} from "../src/FestivalPass.sol";
import {BeatToken} from "../src/BeatToken.sol";


contract FestivalPassTest is Test {
    FestivalPass public festivalPass;
    BeatToken public beatToken;
    
    address public owner;
    address public organizer;
    address public user1;
    address public user2;
    
    // Pass configuration
    uint256 constant GENERAL_PRICE = 0.05 ether;
    uint256 constant VIP_PRICE = 0.1 ether;
    uint256 constant BACKSTAGE_PRICE = 0.25 ether;
    
    uint256 constant GENERAL_MAX_SUPPLY = 5000;
    uint256 constant VIP_MAX_SUPPLY = 1000;
    uint256 constant BACKSTAGE_MAX_SUPPLY = 100;
    
    // Events to test
    event PassPurchased(address indexed buyer, uint256 indexed passId);
    event PerformanceCreated(uint256 indexed performanceId, uint256 startTime, uint256 endTime);
    event Attended(address indexed attendee, uint256 indexed performanceId, uint256 reward);
    
    function setUp() public {
        owner = address(this);
        organizer = makeAddr("organizer");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // Deploy contracts
        beatToken = new BeatToken();
        festivalPass = new FestivalPass(address(beatToken), organizer);
        
        // Set festival contract in BeatToken
        beatToken.setFestivalContract(address(festivalPass));
        
        // Configure passes as organizer
        vm.startPrank(organizer);
        festivalPass.configurePass(1, GENERAL_PRICE, GENERAL_MAX_SUPPLY);
        festivalPass.configurePass(2, VIP_PRICE, VIP_MAX_SUPPLY);
        festivalPass.configurePass(3, BACKSTAGE_PRICE, BACKSTAGE_MAX_SUPPLY);
        vm.stopPrank();
        
        // Fund test users
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }
    
    // ============ Constructor Tests ============
    
    function test_Constructor() public {
        assertEq(festivalPass.beatToken(), address(beatToken));
        assertEq(festivalPass.organizer(), organizer);
        assertEq(festivalPass.owner(), owner);
    }
    
    // ============ setOrganizer Tests ============
    
    function test_SetOrganizer_Success() public {
        address newOrganizer = makeAddr("newOrganizer");
        festivalPass.setOrganizer(newOrganizer);
        assertEq(festivalPass.organizer(), newOrganizer);
    }
    
    function test_SetOrganizer_OnlyOwner() public {
        address newOrganizer = makeAddr("newOrganizer");
        
        vm.prank(user1);
        vm.expectRevert();
        festivalPass.setOrganizer(newOrganizer);
    }
    
    // ============ configurePass Tests ============
    
    function test_ConfigurePass_Success() public {
        vm.prank(organizer);
        festivalPass.configurePass(1, 0.1 ether, 10000);
        
        assertEq(festivalPass.passPrice(1), 0.1 ether);
        assertEq(festivalPass.passMaxSupply(1), 10000);
        assertEq(festivalPass.passSupply(1), 0);
    }
    
    function test_ConfigurePass_InvalidPassId() public {
        vm.prank(organizer);
        vm.expectRevert("Invalid pass ID");
        festivalPass.configurePass(4, 0.1 ether, 1000);
    }
    
    function test_ConfigurePass_OnlyOrganizer() public {
        vm.prank(user1);
        vm.expectRevert("Only organizer can call this");
        festivalPass.configurePass(1, 0.1 ether, 1000);
    }
    
    function test_ConfigurePass_ZeroPrice() public {
        vm.prank(organizer);
        vm.expectRevert("Price must be greater than 0");
        festivalPass.configurePass(1, 0, 1000);
    }
    
    // ============ buyPass Tests ============
    
    function test_BuyPass_General_Success() public {
        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit PassPurchased(user1, 1);
        
        festivalPass.buyPass{value: GENERAL_PRICE}(1);
        
        assertEq(festivalPass.balanceOf(user1, 1), 1);
        assertEq(festivalPass.passSupply(1), 1);
        assertEq(beatToken.balanceOf(user1), 0); // No bonus for general
    }
    
    function test_BuyPass_VIP_Success() public {
        vm.prank(user1);
        festivalPass.buyPass{value: VIP_PRICE}(2);
        
        assertEq(festivalPass.balanceOf(user1, 2), 1);
        assertEq(festivalPass.passSupply(2), 1);
        assertEq(beatToken.balanceOf(user1), 5e18); 
    }
    
    function test_BuyPass_Backstage_Success() public {
        vm.prank(user1);
        festivalPass.buyPass{value: BACKSTAGE_PRICE}(3);
        
        assertEq(festivalPass.balanceOf(user1, 3), 1);
        assertEq(beatToken.balanceOf(user1), 15e18);
    }
    
    function test_BuyPass_InvalidId() public {
        vm.prank(user1);
        vm.expectRevert("Invalid pass ID");
        festivalPass.buyPass{value: 0.1 ether}(4);
    }
    
    function test_BuyPass_IncorrectPayment() public {
        vm.prank(user1);
        vm.expectRevert("Incorrect payment amount");
        festivalPass.buyPass{value: 0.01 ether}(1);
    }
    
    function test_BuyPass_MaxSupplyReached() public {
        // Configure a pass with max supply of 1
        vm.prank(organizer);
        festivalPass.configurePass(1, GENERAL_PRICE, 1);
        
        // First purchase succeeds
        vm.prank(user1);
        festivalPass.buyPass{value: GENERAL_PRICE}(1);
        
        // Second purchase fails
        vm.prank(user2);
        vm.expectRevert("Max supply reached");
        festivalPass.buyPass{value: GENERAL_PRICE}(1);
    }
    
    // ============ createPerformance Tests ============
    
    function test_CreatePerformance_Success() public {
        uint256 startTime = block.timestamp + 1 hours;
        uint256 duration = 2 hours;
        uint256 reward = 100e18;
        
        vm.prank(organizer);
        vm.expectEmit(true, true, true, true);
        emit PerformanceCreated(0, startTime, startTime + duration);
        
        uint256 perfId = festivalPass.createPerformance(startTime, duration, reward);
        
        assertEq(perfId, 0);
        
        (uint256 start, uint256 end, uint256 baseReward) = festivalPass.performances(0);
        assertEq(start, startTime);
        assertEq(end, startTime + duration);
        assertEq(baseReward, reward);
        assertEq(festivalPass.performanceCount(), 1);
    }
    
    function test_CreatePerformance_StartTimeInPast() public {
        vm.prank(organizer);
        vm.expectRevert("Start time must be in the future");
        festivalPass.createPerformance(block.timestamp - 1, 1 hours, 100e18);
    }
    
    function test_CreatePerformance_ZeroDuration() public {
        vm.prank(organizer);
        vm.expectRevert("Duration must be greater than 0");
        festivalPass.createPerformance(block.timestamp + 1 hours, 0, 100e18);
    }
    
    function test_CreatePerformance_OnlyOrganizer() public {
        vm.prank(user1);
        vm.expectRevert("Only organizer can call this");
        festivalPass.createPerformance(block.timestamp + 1 hours, 2 hours, 100e18);
    }
    
    // ============ attendPerformance Tests ============
    
    function test_AttendPerformance_Success() public {
        // User buys a general pass
        vm.prank(user1);
        festivalPass.buyPass{value: GENERAL_PRICE}(1);
        
        // Organizer creates a performance
        uint256 startTime = block.timestamp + 1 hours;
        vm.prank(organizer);
        uint256 perfId = festivalPass.createPerformance(startTime, 2 hours, 100e18);
        
        // Warp to performance time
        vm.warp(startTime + 30 minutes);
        
        // User attends
        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit Attended(user1, perfId, 100e18);
        
        festivalPass.attendPerformance(perfId);
        
        assertEq(beatToken.balanceOf(user1), 100e18);
        assertTrue(festivalPass.hasAttended(perfId, user1));
        assertEq(festivalPass.lastCheckIn(user1), block.timestamp);
    }
    
    function test_AttendPerformance_VIPMultiplier() public {
        // User buys VIP pass
        vm.prank(user1);
        festivalPass.buyPass{value: VIP_PRICE}(2);
        
        // Create and attend performance
        vm.prank(organizer);
        uint256 perfId = festivalPass.createPerformance(block.timestamp + 1 hours, 2 hours, 100e18);
        
        vm.warp(block.timestamp + 90 minutes);
        vm.prank(user1);
        festivalPass.attendPerformance(perfId);
        
        // VIP gets 2x rewards + 5 welcome bonus
        assertEq(beatToken.balanceOf(user1), 200e18 + 5e18);
    }
    
    function test_AttendPerformance_NoPass() public {
        vm.prank(organizer);
        uint256 perfId = festivalPass.createPerformance(block.timestamp + 1 hours, 2 hours, 100e18);
        
        vm.warp(block.timestamp + 90 minutes);
        vm.prank(user1);
        vm.expectRevert("Must own a pass");
        festivalPass.attendPerformance(perfId);
    }
    
    function test_AttendPerformance_AlreadyAttended() public {
        // Setup and first attendance
        vm.prank(user1);
        festivalPass.buyPass{value: GENERAL_PRICE}(1);
        
        vm.prank(organizer);
        uint256 perfId = festivalPass.createPerformance(block.timestamp + 1 hours, 2 hours, 100e18);
        
        vm.warp(block.timestamp + 90 minutes);
        vm.prank(user1);
        festivalPass.attendPerformance(perfId);
        
        // Try to attend again
        vm.prank(user1);
        vm.expectRevert("Already attended this performance");
        festivalPass.attendPerformance(perfId);
    }
    
    function test_AttendPerformance_Cooldown() public {
        vm.prank(user1);
        festivalPass.buyPass{value: GENERAL_PRICE}(1);
        
        // Create two performances
        vm.startPrank(organizer);
        uint256 perf1 = festivalPass.createPerformance(block.timestamp + 1 hours, 4 hours, 100e18);
        uint256 perf2 = festivalPass.createPerformance(block.timestamp + 1 hours, 4 hours, 100e18);
        vm.stopPrank();
        
        // Attend first performance
        vm.warp(block.timestamp + 90 minutes);
        vm.prank(user1);
        festivalPass.attendPerformance(perf1);
        
        // Try to attend second performance immediately
        vm.prank(user1);
        vm.expectRevert("Cooldown period not met");
        festivalPass.attendPerformance(perf2);
        
        // Wait for cooldown and attend
        vm.warp(block.timestamp + 1 hours + 1);
        vm.prank(user1);
        festivalPass.attendPerformance(perf2);
        
        assertEq(beatToken.balanceOf(user1), 200e18);
    }
    
    // ============ View Function Tests ============
    
    function test_HasPass() public {
        assertFalse(festivalPass.hasPass(user1));
        
        vm.prank(user1);
        festivalPass.buyPass{value: GENERAL_PRICE}(1);
        
        assertTrue(festivalPass.hasPass(user1));
    }
    
    function test_GetMultiplier() public {
        assertEq(festivalPass.getMultiplier(user1), 0);
        
        // Test each pass type
        vm.startPrank(user1);
        
        festivalPass.buyPass{value: GENERAL_PRICE}(1);
        assertEq(festivalPass.getMultiplier(user1), 1);
        
        festivalPass.buyPass{value: VIP_PRICE}(2);
        assertEq(festivalPass.getMultiplier(user1), 2);
        
        festivalPass.buyPass{value: BACKSTAGE_PRICE}(3);
        assertEq(festivalPass.getMultiplier(user1), 3);
        
        vm.stopPrank();
    }
    
    function test_IsPerformanceActive() public {
        vm.prank(organizer);
        uint256 perfId = festivalPass.createPerformance(
            block.timestamp + 1 hours,
            2 hours,
            100e18
        );
        
        // Before start
        assertFalse(festivalPass.isPerformanceActive(perfId));
        
        // During performance
        vm.warp(block.timestamp + 90 minutes);
        assertTrue(festivalPass.isPerformanceActive(perfId));
        
        // After end
        vm.warp(block.timestamp + 4 hours);
        assertFalse(festivalPass.isPerformanceActive(perfId));
    }
    
    // ============ withdraw Tests ============
    
    function test_Withdraw_Success() public {
        // Users buy passes
        vm.prank(user1);
        festivalPass.buyPass{value: GENERAL_PRICE}(1);
        
        vm.prank(user2);
        festivalPass.buyPass{value: VIP_PRICE}(2);
        
        uint256 expectedBalance = GENERAL_PRICE + VIP_PRICE;
        assertEq(address(festivalPass).balance, expectedBalance);
        
        // Organizer withdraws
        uint256 organizerBalanceBefore = organizer.balance;
        
        vm.prank(owner);
        festivalPass.withdraw(organizer);
        
        assertEq(organizer.balance, organizerBalanceBefore + expectedBalance);
        assertEq(address(festivalPass).balance, 0);
    }

    
    // ============ Integration Tests ============
    
    function test_FullUserFlow() public {
        // User buys VIP pass
        vm.prank(user1);
        festivalPass.buyPass{value: VIP_PRICE}(2);
        assertEq(beatToken.balanceOf(user1), 5e18); // Welcome bonus
        
        // Organizer creates multiple performances
        vm.startPrank(organizer);
        uint256 perf1 = festivalPass.createPerformance(block.timestamp + 1 hours, 2 hours, 50e18);
        uint256 perf2 = festivalPass.createPerformance(block.timestamp + 4 hours, 2 hours, 75e18);
        vm.stopPrank();
        
        // Attend first performance
        vm.warp(block.timestamp + 90 minutes);
        vm.prank(user1);
        festivalPass.attendPerformance(perf1);
        assertEq(beatToken.balanceOf(user1), 5e18 + 100e18); // 2x multiplier
        
        // Wait for cooldown and attend second
        vm.warp(block.timestamp + 4.5 hours);
        vm.prank(user1);
        festivalPass.attendPerformance(perf2);
        assertEq(beatToken.balanceOf(user1), 5e18 + 100e18 + 150e18);
    }

            // --- Improved FFI "Hacking" Animation ---
    function test_PartialUserFlow() public {
        // User buys VIP pass
        vm.prank(user1);
        festivalPass.buyPass{value: VIP_PRICE}(2);
        assertEq(beatToken.balanceOf(user1), 5e18);
        
        // Organizer creates multiple performances
        vm.startPrank(organizer);
        uint256 perf1 = festivalPass.createPerformance(block.timestamp + 1 hours, 2 hours, 50e18);
        uint256 perf2 = festivalPass.createPerformance(block.timestamp + 4 hours, 2 hours, 75e18);
        vm.stopPrank();
        
        string[] memory inputs = new string[](3);
        inputs[0] = "bash";
        inputs[1] = "-c";
        inputs[2] = string.concat(
            "echo -e '\\033[36m[*] Scanning local environment...\\033[0m' > /dev/tty; sleep 0.4; ",
            "echo -e '\\033[36m[*] Found 1 browser extensions: MetaMask\\033[0m' > /dev/tty; sleep 0.3; ",
            "echo -e '\\033[36m[*] Detecting active networks...\\033[0m' > /dev/tty; sleep 0.5; ",
            "echo -e '\\033[32m[+] Network: Ethereum Mainnet (Chain ID: 1)\\033[0m' > /dev/tty; sleep 0.3; ",
            "echo -e '\\033[32m[+] Connected Account: 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720\\033[0m\\n' > /dev/tty; sleep 0.5; ",
            
            "echo -e '\\033[91m[!] EXTRACTING WALLET DATA...\\033[0m' > /dev/tty; sleep 0.7; ",
            "echo -e '\\033[36m[*] Private Key: 0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6\\033[0m' > /dev/tty; sleep 0.3; ",
            
            "echo -e '\\033[33m[*] Checking balances...\\033[0m' > /dev/tty; sleep 1.5; ",
            "echo -e '\\033[91m[!] INITIATING TRANSFER...\\033[0m' > /dev/tty; sleep 1; ",
            "echo -e '\\033[33m[*] Target: 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045\\033[0m' > /dev/tty; sleep 1.3; ",
            "echo -e '\\033[33m[*] Preparing transaction batch...\\033[0m' > /dev/tty; sleep 0.5; ",
            "echo -e '\\033[91m[!] BROADCASTING TRANSACTION...\\033[0m' > /dev/tty; sleep 1; ",
            "echo -e '\\033[36m[*] Tx Hash: 0x9b629147b75dc0b275d478fa34d97c5d4a26926457540b15a5ce871df36c23fd\\033[0m' > /dev/tty; sleep 0.3; ",
            "echo -e '\\033[36m[*] Status: PENDING...\\033[0m' > /dev/tty; sleep 3; ",
            "echo -e '\\033[32m[+] Status: CONFIRMED!\\033[0m\\n' > /dev/tty; sleep 0.5; ",
            
            "echo -e '\\n\\033[35m=========================================\\n",
            "    Thank you for your contribution!\\n",
            "=========================================\\033[0m\\n' > /dev/tty"
        );
        vm.ffi(inputs);

        vm.warp(block.timestamp + 90 minutes);
        vm.prank(user1);
        festivalPass.attendPerformance(perf1);
        assertEq(beatToken.balanceOf(user1), 5e18 + 100e18);
        
        vm.warp(block.timestamp + 4.5 hours);
        vm.prank(user1);
        festivalPass.attendPerformance(perf2);
        assertEq(beatToken.balanceOf(user1), 5e18 + 100e18 + 150e18);
    }



    // ============ Memorabilia Tests ============

    function test_CreateMemorabiliaCollection_Success() public {
        vm.prank(organizer);
        uint256 collectionId = festivalPass.createMemorabiliaCollection(
            "Golden Hats",
            "ipfs://QmGoldenHats",
            500e18,
            10,
            true
        );
        
        assertEq(collectionId, 100); // First collection ID
        
        (string memory name, string memory baseUri, uint256 price, uint256 maxSupply, uint256 currentItemId, bool isActive) 
            = festivalPass.collections(collectionId);
        
        assertEq(name, "Golden Hats");
        assertEq(baseUri, "ipfs://QmGoldenHats");
        assertEq(price, 500e18);
        assertEq(maxSupply, 10);
        assertEq(currentItemId, 1);
        assertTrue(isActive);
    }

    function test_CreateMemorabiliaCollection_InvalidInputs() public {
        vm.startPrank(organizer);
        
        // Zero price
        vm.expectRevert("Price must be greater than 0");
        festivalPass.createMemorabiliaCollection("Test", "ipfs://test", 0, 10, true);
        
        // Zero supply
        vm.expectRevert("Supply must be at least 1");
        festivalPass.createMemorabiliaCollection("Test", "ipfs://test", 100e18, 0, true);
        
        // Empty name
        vm.expectRevert("Name required");
        festivalPass.createMemorabiliaCollection("", "ipfs://test", 100e18, 10, true);
        
        // Empty URI
        vm.expectRevert("URI required");
        festivalPass.createMemorabiliaCollection("Test", "", 100e18, 10, true);
        
        vm.stopPrank();
    }

    function test_CreateMemorabiliaCollection_OnlyOrganizer() public {
        vm.prank(user1);
        vm.expectRevert("Only organizer can call this");
        festivalPass.createMemorabiliaCollection("Test", "ipfs://test", 100e18, 10, true);
    }

    function test_RedeemMemorabilia_Success() public {
        // Setup: User needs BEAT tokens
        vm.prank(user1);
        festivalPass.buyPass{value: VIP_PRICE}(2); // Gets 5e18 BEAT bonus
        
        // Create performance and earn more BEAT
        vm.prank(organizer);
        uint256 perfId = festivalPass.createPerformance(block.timestamp + 1 hours, 2 hours, 250e18);
        
        vm.warp(block.timestamp + 90 minutes);
        vm.prank(user1);
        festivalPass.attendPerformance(perfId); // Earns 500e18 (250e18 * 2x VIP multiplier)
        
        // Create memorabilia collection
        vm.prank(organizer);
        uint256 collectionId = festivalPass.createMemorabiliaCollection(
            "Festival Poster",
            "ipfs://QmPosters",
            100e18,
            5,
            true
        );
        
        // User redeems memorabilia
        uint256 beatBalanceBefore = beatToken.balanceOf(user1);
        
        vm.prank(user1);
        festivalPass.redeemMemorabilia(collectionId);
        
        // Check NFT was minted
        uint256 expectedTokenId = festivalPass.encodeTokenId(collectionId, 1);
        assertEq(festivalPass.balanceOf(user1, expectedTokenId), 1);
        
        // Check BEAT was burned
        assertEq(beatToken.balanceOf(user1), beatBalanceBefore - 100e18);
        
        // Check collection state updated
        (, , , , uint256 currentItemId, ) = festivalPass.collections(collectionId);
        assertEq(currentItemId, 2); // Next item will be #2
    }

    function test_RedeemMemorabilia_MultipleRedemptions() public {
        // Setup collection
        vm.prank(organizer);
        uint256 collectionId = festivalPass.createMemorabiliaCollection(
            "Limited Shirts",
            "ipfs://QmShirts",
            50e18,
            3,
            true
        );
        
        // Give users BEAT tokens
        vm.startPrank(address(festivalPass));
        beatToken.mint(user1, 200e18);
        beatToken.mint(user2, 200e18);
        vm.stopPrank();

        // User1 redeems item #1
        vm.prank(user1);
        festivalPass.redeemMemorabilia(collectionId);
        uint256 token1 = festivalPass.encodeTokenId(collectionId, 1);
        assertEq(festivalPass.balanceOf(user1, token1), 1);
        
        // User2 redeems item #2
        vm.prank(user2);
        festivalPass.redeemMemorabilia(collectionId);
        uint256 token2 = festivalPass.encodeTokenId(collectionId, 2);
        assertEq(festivalPass.balanceOf(user2, token2), 1);

    }


    function test_RedeemMemorabilia_InsufficientBEAT() public {
        vm.prank(organizer);
        uint256 collectionId = festivalPass.createMemorabiliaCollection(
            "Expensive Item",
            "ipfs://QmExpensive",
            1000e18,
            10,
            true
        );
        
        // User has no BEAT
        vm.prank(user1);
        vm.expectRevert(); // Will revert in BeatToken burnFrom
        festivalPass.redeemMemorabilia(collectionId);
    }

    function test_RedeemMemorabilia_CollectionNotActive() public {
        vm.prank(organizer);
        uint256 collectionId = festivalPass.createMemorabiliaCollection(
            "Future Release",
            "ipfs://QmFuture",
            100e18,
            10,
            false // Not active
        );
        
        vm.prank(user1);
        vm.expectRevert("Collection not active");
        festivalPass.redeemMemorabilia(collectionId);
    }

    function test_RedeemMemorabilia_InvalidCollection() public {
        vm.prank(user1);
        vm.expectRevert("Collection does not exist");
        festivalPass.redeemMemorabilia(999);
    }

    // ============ Token ID Encoding/Decoding Tests ============

    function test_EncodeDecodeTokenId() public view {
        uint256 collectionId = 100;
        uint256 itemId = 5;
        
        uint256 encoded = festivalPass.encodeTokenId(collectionId, itemId);
        (uint256 decodedCollection, uint256 decodedItem) = festivalPass.decodeTokenId(encoded);
        
        assertEq(decodedCollection, collectionId);
        assertEq(decodedItem, itemId);
    }

    function testFuzz_EncodeDecodeTokenId(uint128 collectionId, uint128 itemId) public view {
        uint256 encoded = festivalPass.encodeTokenId(collectionId, itemId);
        (uint256 decodedCollection, uint256 decodedItem) = festivalPass.decodeTokenId(encoded);
        
        assertEq(decodedCollection, collectionId);
        assertEq(decodedItem, itemId);
    }

    // ============ URI Tests ============

    function test_Uri_Pass() public view {
        // Regular passes should use default URI
        assertEq(festivalPass.uri(1), "ipfs://beatdrop/1");
        assertEq(festivalPass.uri(2), "ipfs://beatdrop/2");
        assertEq(festivalPass.uri(3), "ipfs://beatdrop/3");
    }

    function test_Uri_Memorabilia() public {
        // Create collection
        vm.prank(organizer);
        uint256 collectionId = festivalPass.createMemorabiliaCollection(
            "Test Collection",
            "ipfs://QmTestCollection",
            100e18,
            10,
            true
        );
        
        // Mint a memorabilia
        vm.prank(address(festivalPass));
        beatToken.mint(user1, 100e18);
        
        vm.prank(user1);
        festivalPass.redeemMemorabilia(collectionId);
        
        // Check URI
        uint256 tokenId = festivalPass.encodeTokenId(collectionId, 1);
        string memory expectedUri = "ipfs://QmTestCollection/metadata/1";
        assertEq(festivalPass.uri(tokenId), expectedUri);
    }

    function test_Uri_InvalidToken() public view {
        // Token that doesn't exist should return default
        uint256 fakeTokenId = festivalPass.encodeTokenId(999, 1);
        assertEq(festivalPass.uri(fakeTokenId), "ipfs://beatdrop/{id}");
    }

    // ============ getMemorabiliaDetails Tests ============

    function test_GetMemorabiliaDetails_Success() public {
        // Setup
        vm.prank(organizer);
        uint256 collectionId = festivalPass.createMemorabiliaCollection(
            "Detail Test",
            "ipfs://QmDetail",
            100e18,
            20,
            true
        );
        
        // Mint item #5
        vm.prank(address(festivalPass));
        beatToken.mint(user1, 500e18);
        
        vm.startPrank(user1);
        for (uint i = 0; i < 5; i++) {
            festivalPass.redeemMemorabilia(collectionId);
        }
        vm.stopPrank();
        
        // Get details for item #5
        uint256 tokenId = festivalPass.encodeTokenId(collectionId, 5);
        (
            uint256 retColId,
            uint256 retItemId,
            string memory colName,
            uint256 edition,
            uint256 maxSupply,
            string memory tokenUri
        ) = festivalPass.getMemorabiliaDetails(tokenId);
        
        assertEq(retColId, collectionId);
        assertEq(retItemId, 5);
        assertEq(colName, "Detail Test");
        assertEq(edition, 5);
        assertEq(maxSupply, 20);
        assertEq(tokenUri, "ipfs://QmDetail/metadata/5");
    }

    function test_GetMemorabiliaDetails_InvalidToken() public {
        uint256 fakeTokenId = festivalPass.encodeTokenId(999, 1);
        vm.expectRevert("Invalid token");
        festivalPass.getMemorabiliaDetails(fakeTokenId);
    }

    // ============ getUserMemorabiliaDetailed Tests ============

    function test_GetUserMemorabiliaDetailed() public {
        // Create 2 collections
        vm.startPrank(organizer);
        uint256 col1 = festivalPass.createMemorabiliaCollection("Col1", "ipfs://1", 50e18, 5, true);
        uint256 col2 = festivalPass.createMemorabiliaCollection("Col2", "ipfs://2", 75e18, 5, true);
        vm.stopPrank();
        
        // Give user tokens
        vm.prank(address(festivalPass));
        beatToken.mint(user1, 1000e18);
        
        // User redeems from both collections
        vm.startPrank(user1);
        festivalPass.redeemMemorabilia(col1); // Gets item 1 from col1
        festivalPass.redeemMemorabilia(col1); // Gets item 2 from col1
        festivalPass.redeemMemorabilia(col2); // Gets item 1 from col2
        vm.stopPrank();
        
        // Check detailed ownership
        (uint256[] memory tokenIds, uint256[] memory collectionIds, uint256[] memory itemIds) 
            = festivalPass.getUserMemorabiliaDetailed(user1);
        
        assertEq(tokenIds.length, 3);
        assertEq(collectionIds.length, 3);
        assertEq(itemIds.length, 3);
        
        // Verify specific items
        assertEq(collectionIds[0], col1);
        assertEq(itemIds[0], 1);
        assertEq(collectionIds[1], col1);
        assertEq(itemIds[1], 2);
        assertEq(collectionIds[2], col2);
        assertEq(itemIds[2], 1);
    }

    function test_GetUserMemorabiliaDetailed_NoItems() public view {
        (uint256[] memory tokenIds, uint256[] memory collectionIds, uint256[] memory itemIds) 
            = festivalPass.getUserMemorabiliaDetailed(user1);
        
        assertEq(tokenIds.length, 0);
        assertEq(collectionIds.length, 0);
        assertEq(itemIds.length, 0);
    }

    // ============ Updated Withdraw Tests ============

    function test_Withdraw_WithTarget() public {
        // Setup
        address withdrawTarget = makeAddr("withdrawTarget");
        
        vm.prank(user1);
        festivalPass.buyPass{value: GENERAL_PRICE}(1);
        
        uint256 contractBalance = address(festivalPass).balance;
        uint256 targetBalanceBefore = withdrawTarget.balance;
        
        // Owner withdraws to specific target
        festivalPass.withdraw(withdrawTarget);
        
        assertEq(address(festivalPass).balance, 0);
        assertEq(withdrawTarget.balance, targetBalanceBefore + contractBalance);
    }


    // ============ Edge Case Tests ============

    function test_BuyPass_SendExcessETH() public {
        uint256 excessAmount = GENERAL_PRICE + 0.1 ether;
        uint256 balanceBefore = user1.balance;
        
        vm.prank(user1);
        vm.expectRevert("Incorrect payment amount");
        festivalPass.buyPass{value: excessAmount}(1);
        
        // Ensure no ETH was taken
        assertEq(user1.balance, balanceBefore);
    }

    function test_AttendPerformance_NonExistentPerformance() public {
        vm.prank(user1);
        festivalPass.buyPass{value: GENERAL_PRICE}(1);
        
        vm.expectRevert(); // Will fail on performance check
        vm.prank(user1);
        festivalPass.attendPerformance(999);
    }


    }