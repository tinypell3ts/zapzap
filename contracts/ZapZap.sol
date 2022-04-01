// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DonateNFT is ERC721, ERC721Enumerable, Ownable {
    using SafeERC20 for IERC20;

    constructor(uint256 _fee) ERC721("DonationNFT", "DNT") {
        fee = _fee;
    }

    event DonationCreated(address _donator, uint256 tokenId);
    event DonationRedeemed(
        address _donator,
        uint256 tokenId,
        uint256 donationAmount
    );

    uint256 public maxSupply = 100;
    uint256 public fee = 0;
    mapping(uint256 => uint256) public donations;

    function donate(
        uint256[] calldata tokenIds,
        address zapContract,
        bytes calldata zapData
    ) public payable {
        require(msg.value >= fee, "incorrect amount");
        // Invest msg.value into liquidity pool
        (bool success, ) = zapContract.call{value: msg.value}(zapData);
        require(success, "Zap In Failed");
        // NFT Stuff
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(
                tokenIds[i] <= maxSupply,
                "You have exceeded the supply of tokens."
            );
            _safeMint(msg.sender, tokenIds[i]);
            donations[tokenIds[i]] = msg.value;

            //msg.sender is the person that signs the transaction
            emit DonationCreated(msg.sender, tokenIds[i]);
        }
    }

    function redeem(
        address zapContract,
        bytes calldata zapData,
        address toTokenAddress,
        uint256 tokenId
    ) public payable {
        // ZapOut
        (bool success, ) = zapContract.call(zapData);
        require(success, "Zap Out Failed");
        IERC20(toTokenAddress).safeTransfer(
            msg.sender,
            IERC20(toTokenAddress).balanceOf(address(this))
        );

        //Burn NFT
        _burn(tokenId);
        emit DonationRedeemed(msg.sender, tokenId, donations[tokenId]);
    }

    function approveZaps(
        address zapContract,
        address sellToken,
        uint256 amount
    ) public {
        require(IERC20(sellToken).approve(zapContract, amount));
    }

    function withdraw() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function withdrawERC20(address tokenAddress) public payable onlyOwner {
        IERC20(tokenAddress).safeTransfer(
            msg.sender,
            IERC20(tokenAddress).balanceOf(address(this))
        );
    }

    function balance() public view onlyOwner returns (uint256) {
        return address(this).balance;
    }

    function balanceERC20(address tokenAddress)
        public
        view
        onlyOwner
        returns (uint256)
    {
        return IERC20(tokenAddress).balanceOf(address(this));
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
