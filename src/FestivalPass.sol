//SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "./BeatToken.sol";
import "./Interfaces/IFestivalPass.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract FestivalPass is ERC1155, Ownable2Step, IFestivalPass {
    address public beatToken;
    address public organizer;
    
    uint256 constant COLLECTION_ID_SHIFT = 128;

    // Collection IDs
    uint256 constant GENERAL_PASS = 1;
    uint256 constant VIP_PASS = 2;
    uint256 constant BACKSTAGE_PASS = 3;
    uint256 public nextCollectionId = 100;
     
    // Pass data
    mapping(uint256 => uint256) public passSupply;      // Current minted
    mapping(uint256 => uint256) public passMaxSupply;   // Max allowed
    mapping(uint256 => uint256) public passPrice;       // Price in ETH
    
    // Performance data 
    mapping(uint256 => Performance) public performances;
    mapping(uint256 => mapping(address => bool)) public hasAttended;
    mapping(address => uint256) public lastCheckIn;
    uint256 public performanceCount;

    // Cooldown period for check-ins
    uint256 constant COOLDOWN = 1 hours;

    // Memorabilia collections
    mapping(uint256 => MemorabiliaCollection) public collections; // collectionId => Collection
    mapping(uint256 => uint256) public tokenIdToEdition; // tokenId => edition number

    modifier onlyOrganizer() {
        require(msg.sender == organizer, "Only organizer can call this");
        _;
    }

    constructor(address _beatToken, address _organizer) ERC1155("ipfs://beatdrop/{id}") Ownable(msg.sender){
        setOrganizer(_organizer);
        beatToken = _beatToken;
    }

    function setOrganizer(address _organizer) public onlyOwner {
        organizer = _organizer;
    }

    function configurePass(
        uint256 passId,
        uint256 price,
        uint256 maxSupply
    ) external onlyOrganizer {
        require(passId == GENERAL_PASS || passId == VIP_PASS || passId == BACKSTAGE_PASS, "Invalid pass ID");
        require(price > 0, "Price must be greater than 0");
        require(maxSupply > 0, "Max supply must be greater than 0");

        passPrice[passId] = price;
        passMaxSupply[passId] = maxSupply;
        passSupply[passId] = 0; // Reset current supply
    }

    // Buy a festival pass
    function buyPass(uint256 collectionId) external payable {
        // Must be valid pass ID (1 or 2 or 3)
        require(collectionId == GENERAL_PASS || collectionId == VIP_PASS || collectionId == BACKSTAGE_PASS, "Invalid pass ID");
        // Check payment and supply
        require(msg.value == passPrice[collectionId], "Incorrect payment amount");
        require(passSupply[collectionId] < passMaxSupply[collectionId], "Max supply reached");
        // Mint 1 pass to buyer
        _mint(msg.sender, collectionId, 1, "");
        ++passSupply[collectionId];
        // VIP gets 5 BEAT welcome bonus BACKSTAGE gets 15 BEAT welcome bonus
        uint256 bonus = (collectionId == VIP_PASS) ? 5e18 : (collectionId == BACKSTAGE_PASS) ? 15e18 : 0;
        if (bonus > 0) {
            // Mint BEAT tokens to buyer
            BeatToken(beatToken).mint(msg.sender, bonus);
        }
        emit PassPurchased(msg.sender, collectionId);
    }

    // Organizer creates a performance
    function createPerformance(
        uint256 startTime,
        uint256 duration,
        uint256 reward
    ) external onlyOrganizer returns (uint256) {
        require(startTime > block.timestamp, "Start time must be in the future");
        require(duration > 0, "Duration must be greater than 0");
        // Set start/end times
        performances[performanceCount] = Performance({
            startTime: startTime,
            endTime: startTime + duration,
            baseReward: reward
        });
        emit PerformanceCreated(performanceCount, startTime, startTime + duration);
        return performanceCount++;
    }

    // Attend a performance to earn BEAT
    function attendPerformance(uint256 performanceId) external {
        require(isPerformanceActive(performanceId), "Performance is not active");
        require(hasPass(msg.sender), "Must own a pass");
        require(!hasAttended[performanceId][msg.sender], "Already attended this performance");
        require(block.timestamp >= lastCheckIn[msg.sender] + COOLDOWN, "Cooldown period not met");
        hasAttended[performanceId][msg.sender] = true;
        lastCheckIn[msg.sender] = block.timestamp;
        
        uint256 multiplier = getMultiplier(msg.sender);
        BeatToken(beatToken).mint(msg.sender, performances[performanceId].baseReward * multiplier);
        emit Attended(msg.sender, performanceId, performances[performanceId].baseReward * multiplier);
    }

    // Check if user owns any pass
    function hasPass(address user) public view returns (bool) {
        return balanceOf(user, GENERAL_PASS) > 0 || 
               balanceOf(user, VIP_PASS) > 0 || 
               balanceOf(user, BACKSTAGE_PASS) > 0;
    }
    
        // Get user's reward multiplier based on pass type
    function getMultiplier(address user) public view returns (uint256) {
        if (balanceOf(user, BACKSTAGE_PASS) > 0) {
            return 3; // 3x for BACKSTAGE
        } else if (balanceOf(user, VIP_PASS) > 0) {
            return 2; // 2x for VIP
        } else if (balanceOf(user, GENERAL_PASS) > 0) {
            return 1; // 1x for GENERAL
        }
        return 0; // No pass
    }

    // View function to check if performance is active
    function isPerformanceActive(uint256 performanceId) public view returns (bool) {
        Performance memory perf = performances[performanceId];
        return perf.startTime != 0 && 
               block.timestamp >= perf.startTime && 
               block.timestamp <= perf.endTime;
    }

    // Organizer withdraws ETH
    function withdraw(address target) external onlyOwner {
        payable(target).transfer(address(this).balance);
    }

    // Helper functions to encode/decode token IDs
    function encodeTokenId(uint256 collectionId, uint256 itemId) public pure returns (uint256) {
        return (collectionId << COLLECTION_ID_SHIFT) + itemId;
    }

    function decodeTokenId(uint256 tokenId) public pure returns (uint256 collectionId, uint256 itemId) {
        collectionId = tokenId >> COLLECTION_ID_SHIFT;
        itemId = uint256(uint128(tokenId));
}

    // Create a new memorabilia collection
    function createMemorabiliaCollection(
        string memory name,
        string memory baseUri,
        uint256 priceInBeat,
        uint256 maxSupply,
        bool activateNow
    ) external onlyOrganizer returns (uint256) {
        require(priceInBeat > 0, "Price must be greater than 0");
        require(maxSupply > 0, "Supply must be at least 1");
        require(bytes(name).length > 0, "Name required");
        require(bytes(baseUri).length > 0, "URI required");
        
        uint256 collectionId = nextCollectionId++;
        
        collections[collectionId] = MemorabiliaCollection({
            name: name,
            baseUri: baseUri,
            priceInBeat: priceInBeat,
            maxSupply: maxSupply,
            currentItemId: 1, // Start item IDs at 1
            isActive: activateNow
        });
        
        emit CollectionCreated(collectionId, name, maxSupply);
        return collectionId;
    }

    // Redeem a memorabilia NFT from a collection
    function redeemMemorabilia(uint256 collectionId) external {
        MemorabiliaCollection storage collection = collections[collectionId];
        require(collection.priceInBeat > 0, "Collection does not exist");
        require(collection.isActive, "Collection not active");
        require(collection.currentItemId < collection.maxSupply, "Collection sold out");
        
        // Burn BEAT tokens
        BeatToken(beatToken).burnFrom(msg.sender, collection.priceInBeat);
        
        // Generate unique token ID
        uint256 itemId = collection.currentItemId++;
        uint256 tokenId = encodeTokenId(collectionId, itemId);
        
        // Store edition number
        tokenIdToEdition[tokenId] = itemId;
        
        // Mint the unique NFT
        _mint(msg.sender, tokenId, 1, "");
        
        emit MemorabiliaRedeemed(msg.sender, tokenId, collectionId, itemId);
}

    // Override URI to handle collections and items
    function uri(uint256 tokenId) public view override returns (string memory) {
        // Handle regular passes (IDs 1-3)
        if (tokenId <= BACKSTAGE_PASS) {
            return string(abi.encodePacked("ipfs://beatdrop/", Strings.toString(tokenId)));
        }
        
        // Decode collection and item IDs
        (uint256 collectionId, uint256 itemId) = decodeTokenId(tokenId);
        
        // Check if it's a valid memorabilia token
        if (collections[collectionId].priceInBeat > 0) {
            // Return specific URI for this item
            // e.g., "ipfs://QmXXX/metadata/5" for item #5
            return string(abi.encodePacked(
                collections[collectionId].baseUri,
                "/metadata/",
                Strings.toString(itemId)
            ));
        }
        
        return super.uri(tokenId);
    }

    // Get details about a specific memorabilia token
    function getMemorabiliaDetails(uint256 tokenId) external view returns (
        uint256 collectionId,
        uint256 itemId,
        string memory collectionName,
        uint256 editionNumber,
        uint256 maxSupply,
        string memory tokenUri
    ) {
        (collectionId, itemId) = decodeTokenId(tokenId);
        MemorabiliaCollection memory collection = collections[collectionId];
        
        require(collection.priceInBeat > 0, "Invalid token");
        
        return (
            collectionId,
            itemId,
            collection.name,
            itemId, // Edition number is the item ID
            collection.maxSupply,
            uri(tokenId)
        );
    }


    // Get all memorabilia owned by a user with details
    function getUserMemorabiliaDetailed(address user) external view returns (
        uint256[] memory tokenIds,
        uint256[] memory collectionIds,
        uint256[] memory itemIds
    ) {
        // First, count how many memorabilia they own
        uint256 count = 0;
        for (uint256 cId = 1; cId < nextCollectionId; cId++) {
            for (uint256 iId = 1; iId < collections[cId].currentItemId; iId++) {
                uint256 tokenId = encodeTokenId(cId, iId);
                if (balanceOf(user, tokenId) > 0) {
                    count++;
                }
            }
        }
        
        // Then populate arrays
        tokenIds = new uint256[](count);
        collectionIds = new uint256[](count);
        itemIds = new uint256[](count);
        
        uint256 index = 0;
        for (uint256 cId = 1; cId < nextCollectionId; cId++) {
            for (uint256 iId = 1; iId < collections[cId].currentItemId; iId++) {
                uint256 tokenId = encodeTokenId(cId, iId);
                if (balanceOf(user, tokenId) > 0) {
                    tokenIds[index] = tokenId;
                    collectionIds[index] = cId;
                    itemIds[index] = iId;
                    index++;
                }
            }
        }
        
        return (tokenIds, collectionIds, itemIds);
    }
}
