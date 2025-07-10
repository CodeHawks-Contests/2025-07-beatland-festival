//SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

contract BeatToken is ERC20, Ownable2Step {
    address public festivalContract;

    constructor() ERC20("BeatDrop Token", "BEAT") Ownable(msg.sender){
    }

    function setFestivalContract(address _festival) external onlyOwner {
        require(festivalContract == address(0), "Festival contract already set"); //@audit cannot be reused for other festivals
        festivalContract = _festival;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == festivalContract, "Only_Festival_Mint");
        _mint(to, amount);
    }


    function burnFrom(address from, uint256 amount) external {
        require(msg.sender == festivalContract, "Only_Festival_Burn");
        _burn(from, amount);
    }
}