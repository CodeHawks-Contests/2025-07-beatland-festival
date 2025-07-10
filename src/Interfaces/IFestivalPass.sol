// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
 * @title IFestivalPass
 * @author InAllHonesty
 * @notice Interface for the BeatDrop Festival Pass system
 * @dev This interface defines the structure for a festival pass NFT system using ERC1155,
 * where users can purchase passes, attend performances to earn BEAT tokens, and redeem
 * unique memorabilia NFTs using their earned tokens.
 */
interface IFestivalPass {

    // ========== STRUCTS ==========

    /**
     * @notice Represents a festival performance/show
     * @dev Performances are time-bounded events where pass holders can check in (and attend) to earn rewards
     * @param startTime Unix timestamp when the performance begins
     * @param endTime Unix timestamp when the performance ends
     * @param baseReward Base amount of BEAT tokens awarded for attendance (before multipliers)
     */
    struct Performance {
        uint256 startTime;
        uint256 endTime;
        uint256 baseReward;
    }
    
    /**
     * @notice Represents a collection of memorabilia NFTs
     * @dev Each collection can have multiple unique items with sequential IDs
     * @param name Human-readable name of the collection
     * @param baseUri Base URI for metadata (e.g., "ipfs://QmXXX"), individual items append "/metadata/{itemId}"
     * @param priceInBeat Cost in BEAT tokens to redeem one item from this collection
     * @param maxSupply Maximum number of items that can be minted in this collection
     * @param currentItemId Next item ID to be minted (starts at 1)
     * @param isActive Whether redemption is currently enabled for this collection
     */
    struct MemorabiliaCollection {
        string name;
        string baseUri;
        uint256 priceInBeat;     
        uint256 maxSupply;       
        uint256 currentItemId;
        bool isActive;
    }

    // ========== EVENTS ==========

    /**
     * @notice Emitted when a festival pass is purchased
     * @param buyer Address of the pass purchaser
     * @param passId Type of pass purchased (1=GENERAL, 2=VIP, 3=BACKSTAGE)
     */
    event PassPurchased(address indexed buyer, uint256 indexed passId);

    /**
     * @notice Emitted when a new performance is scheduled
     * @param performanceId Unique identifier for the performance
     * @param startTime Unix timestamp when the performance begins
     * @param endTime Unix timestamp when the performance ends
     */
    event PerformanceCreated(uint256 indexed performanceId, uint256 startTime, uint256 endTime);

    /**
     * @notice Emitted when a pass holder attends a performance
     * @param attendee Address of the attendee
     * @param performanceId ID of the performance attended
     * @param reward Amount of BEAT tokens earned (including multipliers)
     */
    event Attended(address indexed attendee, uint256 indexed performanceId, uint256 reward);

    /**
     * @notice Emitted when the organizer withdraws collected funds
     * @param organizer Address of the organizer
     * @param amount Amount of ETH withdrawn
     */
    event FundsWithdrawn(address indexed organizer, uint256 amount);

    /**
     * @notice Emitted when a new memorabilia collection is created
     * @param collectionId Unique identifier for the collection
     * @param name Name of the collection
     * @param maxSupply Maximum items available in this collection
     */
    event CollectionCreated(uint256 indexed collectionId, string name, uint256 maxSupply);

    /**
     * @notice Emitted when a memorabilia NFT is redeemed
     * @param collector Address of the collector
     * @param tokenId Full ERC1155 token ID (encodes both collection and item)
     * @param collectionId ID of the collection
     * @param itemId Sequential item number within the collection
     */
    event MemorabiliaRedeemed(address indexed collector, uint256 indexed tokenId, uint256 collectionId, uint256 itemId);

    // ========== PASS MANAGEMENT ==========

    /**
     * @notice Configure pricing and supply for a pass type
     * @dev Only callable by organizer
     * @param passId Pass type (1=GENERAL, 2=VIP, 3=BACKSTAGE)
     * @param price Price in wei to purchase this pass type
     * @param maxSupply Maximum number of passes that can be sold
     */
    function configurePass(uint256 passId, uint256 price, uint256 maxSupply) external;

    /**
     * @notice Purchase a festival pass
     * @dev Mints pass NFT and distributes welcome bonus BEAT tokens for VIP/BACKSTAGE
     * @param collectionId Pass type to purchase (1=GENERAL, 2=VIP, 3=BACKSTAGE)
     */
    function buyPass(uint256 collectionId) external payable;
    
    // ========== PERFORMANCE MANAGEMENT ==========

    /**
     * @notice Create a new performance
     * @dev Only callable by organizer. Performance must start in the future.
     * @param startTime Unix timestamp when performance begins
     * @param duration Length of performance in seconds
     * @param reward Base BEAT token reward for attendance
     * @return performanceId Unique identifier for the created performance
     */
    function createPerformance(uint256 startTime, uint256 duration, uint256 reward) external returns (uint256);

    /**
     * @notice Check into a performance to earn BEAT rewards
     * @dev Requires active performance, valid pass, and cooldown period met
     * @param performanceId ID of the performance to attend
     */
    function attendPerformance(uint256 performanceId) external;
    
    // ========== MEMORABILIA MANAGEMENT ==========

    /**
     * @notice Create a new memorabilia collection
     * @dev Only callable by organizer. Each item in collection has unique token ID.
     * @param name Display name for the collection
     * @param baseUri Base metadata URI (items will be at baseUri/metadata/itemId)
     * @param priceInBeat Cost in BEAT tokens to redeem one item
     * @param maxSupply Maximum items that can exist in this collection
     * @param activateNow Whether redemption should be immediately available
     * @return collectionId Unique identifier for the created collection
     */
    function createMemorabiliaCollection(
        string memory name,
        string memory baseUri,
        uint256 priceInBeat,
        uint256 maxSupply,
        bool activateNow
    ) external returns (uint256);

    /**
     * @notice Redeem a memorabilia NFT using BEAT tokens
     * @dev Burns BEAT tokens and mints unique NFT with encoded collection/item ID
     * @param collectionId ID of the collection to redeem from
     */
    function redeemMemorabilia(uint256 collectionId) external;
    
    // ========== VIEW FUNCTIONS ==========

    /**
     * @notice Check if an address owns any festival pass
     * @param user Address to check
     * @return Whether the user owns at least one pass
     */
    function hasPass(address user) external view returns (bool);

    /**
     * @notice Get BEAT reward multiplier based on pass type
     * @dev GENERAL=1x, VIP=2x, BACKSTAGE=3x, None=0x
     * @param user Address to check
     * @return Reward multiplier (0 if no pass owned)
     */
    function getMultiplier(address user) external view returns (uint256);

    /**
     * @notice Check if a performance is currently active
     * @param performanceId ID of the performance
     * @return Whether the performance is currently active
     */
    function isPerformanceActive(uint256 performanceId) external view returns (bool);

    /**
     * @notice Encode collection and item IDs into a single token ID
     * @dev Uses bit shifting: tokenId = (collectionId << 128) + itemId
     * @param collectionId Collection identifier
     * @param itemId Item number within collection
     * @return Encoded token ID
     */
    function encodeTokenId(uint256 collectionId, uint256 itemId) external pure returns (uint256);

    /**
     * @notice Decode a token ID into collection and item components
     * @param tokenId Encoded token ID
     * @return collectionId Collection identifier
     * @return itemId Item number within collection
     */
    function decodeTokenId(uint256 tokenId) external pure returns (uint256 collectionId, uint256 itemId);

    /**
     * @notice Get detailed information about a memorabilia token
     * @param tokenId Encoded token ID
     * @return collectionId Collection this token belongs to
     * @return itemId Item number within the collection
     * @return collectionName Name of the collection
     * @return editionNumber Edition number (same as itemId)
     * @return maxSupply Total items in the collection
     * @return tokenUri Metadata URI for this specific token
     */
    function getMemorabiliaDetails(uint256 tokenId) external view returns (
        uint256 collectionId,
        uint256 itemId,
        string memory collectionName,
        uint256 editionNumber,
        uint256 maxSupply,
        string memory tokenUri
    );

    /**
     * @notice Get all memorabilia tokens owned by a user
     * @dev Returns parallel arrays with token details
     * @param user Address to query
     * @return tokenIds Array of full token IDs owned
     * @return collectionIds Array of collection IDs for each token
     * @return itemIds Array of item IDs within each collection
     */
    function getUserMemorabiliaDetailed(address user) external view returns (
        uint256[] memory tokenIds,
        uint256[] memory collectionIds,
        uint256[] memory itemIds
    );
    
    // ========== ADMIN FUNCTIONS ==========

    /**
     * @notice Update the festival organizer address
     * @dev Only callable by contract owner
     * @param _organizer New organizer address
     */
    function setOrganizer(address _organizer) external;

    /**
     * @notice Withdraw collected ETH from pass sales
     * @dev Only callable by contract owner, sends to a target inputed by the owner
     * @param target Address to receive the withdrawn funds
     */
    function withdraw(address target) external;
}