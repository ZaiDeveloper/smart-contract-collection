// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "hardhat/console.sol";

contract NftMystery is ERC721URIStorage, Ownable {
    // unique token counter
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    // store batch details
    struct batch {
        string name; //batch 1
        uint256 release_date; //timestamp
        uint256 total_supply;
        uint256 total_sold;
        uint256 price; // in wei
    }
    mapping(uint256 => batch) public batchs;
    
    // store all character for each batch
    struct characterBatchs {
        uint256 token;
        bool sold;
    }
    mapping(uint256 => characterBatchs[]) public AllCharacterBatchs; //uint256 = batch ID

    // reserve index by batch
    mapping(uint256 => mapping(uint256 => bool)) public reserveIndex; //uint256 = Batchs Id, uint256 = index character Batchs

    //store buyer collection
    struct buyerCollections {
        uint256 batchId;
        uint256 nftToken;
        bool reveal;
    }
    mapping(address => buyerCollections[]) public AllBuyerCollections;

    //set constructor
    constructor() ERC721("MyNFT", "NFT") {
        //init batch
        batchs[1].name = "Batch 1";
        batchs[1].release_date = 1652115158; //Wednesday, 15 June 2022 00:00:00
        // batchs[1].release_date = 1655222400; //Wednesday, 15 June 2022 00:00:00
        batchs[1].total_supply = 1111;
        batchs[1].total_sold = 0;
        batchs[1].price = 100000000000000;

        batchs[2].name = "Batch 2";
        batchs[2].release_date = 1655827200; //Wednesday, 22 June 2022 00:00:00
        batchs[2].total_supply = 2222;
        batchs[2].total_sold = 0;
        batchs[2].price = 100000000000000;

        batchs[3].name = "Batch 3";
        batchs[3].release_date = 1656604800; //Wednesday, 1 July 2022 00:00:00
        batchs[3].total_supply = 4444;
        batchs[3].total_sold = 0;
        batchs[3].price = 100000000000000;
    }

    //register character into batch
    function storeCharacterGroup(string memory _uri) public {
        // only owner allow
        require(msg.sender == owner(), "You're not a owner.");

        //set a new token id for the token to be minted
        _tokenIdCounter.increment();
        uint256 token = _tokenIdCounter.current();

        _safeMint(msg.sender, token); //mint the token to owner
        _setTokenURI(token, _uri); //generate the URI

        // get correct batch by token counter
        uint256 batchId = 1;
        if(token > 1111 && token <= 2222) {
            batchId = 2;
        } else if(token > 4444) {
            batchId = 3;
        }

        //bind to character batch
        characterBatchs memory characterBatch = characterBatchs(token, false);
        AllCharacterBatchs[batchId].push(characterBatch);
    }

    //upload nft metadata into batch
    function buyNftMystery(uint256 batchId) // 1, 2 & 3
        public
        payable 
    {        
        // only buyer allow
        require(msg.sender != owner(), "Owner not allow to buy.");

        // check valid batch Id
        bool validBatch = false;
        if(batchId != 1 || batchId != 2 || batchId != 3) {
            validBatch = true;
        }
        require(validBatch, "Batch Id not Valid.");

        // minimum value allowed to be sent
        require(msg.value == batchs[batchId].price, "Please enter the same price to continue your purchase."); // in wei
        
        // get random index based on batch
        uint256 randomIndex = randomIndexByBatch(batchId);

        // is sold
        require(AllCharacterBatchs[batchId][randomIndex].sold != true, "Invalid random index.");

        // update nft to sold status
        AllCharacterBatchs[batchId][randomIndex].sold = true;

        // add reserve index (prevent duplicate index)
        reserveIndex[batchId][randomIndex] = true;

        //update batch sold
        batchs[batchId].total_sold += 1;

        // mapping data into buyerCollections
        buyerCollections memory buyerCollection = buyerCollections(batchId, AllCharacterBatchs[batchId][randomIndex].token, false);
        AllBuyerCollections[msg.sender].push(buyerCollection);
    }

    // get random index based on start and end index by batch
    function randomIndexByBatch(uint256 batchId) public view returns (uint256) {
        bool uniqueIndex = false;
        uint256 randomNumber;

        // loop for prevent duplicate (unique number)
        while (!uniqueIndex) {
            randomNumber = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender))) % batchs[batchId].total_supply ;
            randomNumber = randomNumber + 0;
        
            // check reserve
            if(!reserveIndex[batchId][randomNumber]) {
                uniqueIndex = true;
            }
        }

        return randomNumber;
    }

    // get single collection by index (use myTotalCollections as reference)
    function myCollections(uint _index) public view returns(uint256, string memory, bool) {
        // check collection based on address
        require(myTotalCollections() > 0, "No purchase record.");

        // check reveal status, hide uri if status is false
        string memory nftUri;
        if(AllBuyerCollections[msg.sender][_index].reveal) {
            nftUri = tokenURI(AllBuyerCollections[msg.sender][_index].nftToken);
        }

        return (
            AllBuyerCollections[msg.sender][_index].nftToken, 
            nftUri,
            AllBuyerCollections[msg.sender][_index].reveal
        );
    }

    // get total collection
    function myTotalCollections() public view returns(uint256) {
        return AllBuyerCollections[msg.sender].length;
    }

    function requestReveal() public {
        // check collection based on address
        require(myTotalCollections() > 0, "No purchase record.");

        //loop all buyer collection
        for(uint256 i=0; i < myTotalCollections(); i++) {
            //check batch release & sold out
            if(block.timestamp >= batchs[AllBuyerCollections[msg.sender][i].batchId].release_date 
            && batchs[AllBuyerCollections[msg.sender][i].batchId].total_supply == batchs[AllBuyerCollections[msg.sender][i].batchId].total_sold) {
                //update nft token to reveal true
                AllBuyerCollections[msg.sender][i].reveal = true;
            }
        }
    }

    // returning the contract's balance in wei
    function getBalance() public view returns(uint){
        return address(this).balance;
    }
}