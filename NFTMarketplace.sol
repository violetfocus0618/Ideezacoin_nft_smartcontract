// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "hardhat/console.sol";

contract NFTMarketplace is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _itemsSold;
    Counters.Counter public auctionIds;

    uint256 listingPrice = 0 ether;
    address payable owner;

    mapping(uint256 => MarketItem) private idToMarketItem;

    struct MarketItem {
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        bool sold;
    }
    event MarketItemCreated(
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool sold
    );
    struct Auction {
        address payable ownerAddress;
        address tokenAddress;
        uint256 tokenId;
        uint256 minBidAmount;
        uint256 highestBidAmount;
        address payable highestBidder;
        bool sold;
    }
    Auction[] public auctions;
    mapping(uint256 => bool) public auctionIsLive;
    mapping(address => mapping(uint256 => bool)) public tokenIsForSale;

    event AuctionCreated(
        uint256 auctionId,
        address tokenAddress,
        uint256 tokenId,
        uint256 minBidAmount
    );
    event BidPlaced(
        uint256 auctionId,
        address payable bidder,
        uint256 bidAmount
    );
    event AuctionFinalized(uint256 auctionId, bool sold);

    constructor() ERC721("Ideeza", "IDZ") {
        owner = payable(msg.sender);
    }

    /* Updates the listing price of the contract */
    function updateListingPrice(uint256 _listingPrice) public payable {
        require(
            owner == msg.sender,
            "Only marketplace owner can update listing price."
        );
        listingPrice = _listingPrice;
    }

    /* Returns the listing price of the contract */
    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }

    /* Mints a token and lists it in the marketplace */
    function createToken(string memory tokenURI, uint256 price)
        public
        payable
        returns (uint256)
    {
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        _mint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        createMarketItem(newTokenId, price);
        return newTokenId;
    }

    function createMarketItem(uint256 tokenId, uint256 price) private {
        require(price > 0, "Price must be at least 1 wei");
        require(
            msg.value == listingPrice,
            "Price must be equal to listing price"
        );

        idToMarketItem[tokenId] = MarketItem(
            tokenId,
            payable(msg.sender),
            payable(address(this)),
            price,
            false
        );

        _transfer(msg.sender, address(this), tokenId);
        emit MarketItemCreated(
            tokenId,
            msg.sender,
            address(this),
            price,
            false
        );
    }

    /* allows someone to resell a token they have purchased */
    function resellToken(uint256 tokenId, uint256 price) public payable {
        require(
            idToMarketItem[tokenId].owner == msg.sender,
            "Only item owner can perform this operation"
        );
        require(
            msg.value == listingPrice,
            "Price must be equal to listing price"
        );
        idToMarketItem[tokenId].sold = false;
        idToMarketItem[tokenId].price = price;
        idToMarketItem[tokenId].seller = payable(msg.sender);
        idToMarketItem[tokenId].owner = payable(address(this));
        _itemsSold.decrement();

        _transfer(msg.sender, address(this), tokenId);
    }

    /* Creates the sale of a marketplace item */
    /* Transfers ownership of the item, as well as funds between parties */
    function createMarketSale(uint256 tokenId) public payable {
        uint256 price = idToMarketItem[tokenId].price;
        address seller = idToMarketItem[tokenId].seller;
        require(
            msg.value == price,
            "Please submit the asking price in order to complete the purchase"
        );
        idToMarketItem[tokenId].owner = payable(msg.sender);
        idToMarketItem[tokenId].sold = true;
        idToMarketItem[tokenId].seller = payable(address(0));
        _itemsSold.increment();
        _transfer(address(this), msg.sender, tokenId);
        payable(owner).transfer(listingPrice);
        payable(seller).transfer(msg.value);
    }

    /* Returns all unsold market items */
    function fetchMarketItems() public view returns (MarketItem[] memory) {
        uint256 itemCount = _tokenIds.current();
        uint256 unsoldItemCount = _tokenIds.current() - _itemsSold.current();
        uint256 currentIndex = 0;

        MarketItem[] memory items = new MarketItem[](unsoldItemCount);
        for (uint256 i = 0; i < itemCount; i++) {
            if (idToMarketItem[i + 1].owner == address(this)) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /* Returns only items that a user has purchased */
    function fetchMyNFTs() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _tokenIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /* Returns only items a user has listed */
    function fetchItemsListed() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _tokenIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    function liveAuctionIds() public view returns (uint256[] memory) {
        uint256 liveIdsCount = 0;
        uint256[] memory liveIdsTemp = new uint256[](auctionIds.current());
        for (uint256 i = 0; i < auctionIds.current(); i++) {
            if (auctionIsLive[i]) {
                liveIdsTemp[liveIdsCount] = i;
                liveIdsCount++;
            }
        }

        uint256[] memory liveIds = new uint256[](liveIdsCount);
        for (uint256 i = 0; i < liveIdsCount; i++) {
            liveIds[i] = liveIdsTemp[i];
        }

        return liveIds;
    }

    function createAuction(
        address tokenAddress,
        uint256 tokenId,
        uint256 minBidAmount
    ) public {
        IERC721 token = IERC721(tokenAddress);
        address tokenOwner = token.ownerOf(tokenId);

        require(tokenOwner == msg.sender, "You do not own the NFT");
        require(
            !tokenIsForSale[tokenAddress][tokenId],
            "Token is already for sale"
        );

        Auction memory newAuction = Auction({
            ownerAddress: payable(msg.sender),
            tokenAddress: tokenAddress,
            tokenId: tokenId,
            minBidAmount: minBidAmount,
            highestBidAmount: 0,
            highestBidder: payable(0),
            sold: false
        });
        uint256 newAuctionId = auctionIds.current();
        auctionIsLive[newAuctionId] = true;
        tokenIsForSale[tokenAddress][tokenId] = true;
        auctions.push(newAuction);
        auctionIds.increment();

        emit AuctionCreated(newAuctionId, tokenAddress, tokenId, minBidAmount);
    }

    function placeBid(uint256 auctionId) public payable {
        Auction memory auction = auctions[auctionId];

        require(msg.value > auction.highestBidAmount, "Your bid is too low");

        auction.highestBidder.transfer(auction.highestBidAmount);
        auctions[auctionId].highestBidAmount = msg.value;
        auctions[auctionId].highestBidder = payable(msg.sender);

        emit BidPlaced(auctionId, payable(msg.sender), msg.value);
    }

    function finalizeAuction(uint256 auctionId, bool accept) public {
        Auction memory auction = auctions[auctionId];

        require(auction.ownerAddress == msg.sender, "You are not the seller");

        if (accept) {
            IERC721 token = IERC721(auction.tokenAddress);
            token.safeTransferFrom(
                auction.ownerAddress,
                auction.highestBidder,
                auction.tokenId
            );
            auction.ownerAddress.transfer(auction.highestBidAmount);
            auctions[auctionId].sold = true;
        } else {
            auction.highestBidder.transfer(auction.highestBidAmount);
            auctions[auctionId].sold = false;
        }
        auctionIsLive[auctionId] = false;
        tokenIsForSale[auction.tokenAddress][auction.tokenId] = false;

        emit AuctionFinalized(auctionId, accept);
    }
}
