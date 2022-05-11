// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "hardhat/console.sol";

contract NftBlinkBox is ERC721URIStorage, Ownable {
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
        uint256 datetimeSoldOut; // If all characters have been sold. (timestamp)
        string metadataUri;
        uint256 randomNumber;
    }
    mapping(uint256 => batch) public batchs; // uint256 - batch id

    //store buyer collection
    struct buyerCollections {
        uint256 batchId;
        uint256 tokenTransaction;
        uint256 tokenUri;
        bool reveal;
    }
    mapping(address => buyerCollections[]) public AllBuyerCollections; //address - buyer address

    //set constructor
    constructor() ERC721("MyNFT", "NFT") {
        //init batch
        batchs[1].name = "Batch 1";
        // batchs[1].release_date = 1651334400; //Wednesday, 1 May 2022 00:00:00 - testing only
        batchs[1].release_date = 1655222400; //Wednesday, 15 June 2022 00:00:00
        batchs[1].total_supply = 1111;
        batchs[1].total_sold = 0;
        batchs[1].price = 100000000000000; // wei
        // batchs[1].datetimeSoldOut = 1651852800; //Wednesday, 7 May 2022 00:00:00 - testing only

        batchs[2].name = "Batch 2";
        batchs[2].release_date = 1655827200; //Wednesday, 22 June 2022 00:00:00
        batchs[2].total_supply = 2222;
        batchs[2].total_sold = 0;
        batchs[2].price = 100000000000000; // wei

        batchs[3].name = "Batch 3";
        batchs[3].release_date = 1656604800; //Wednesday, 1 July 2022 00:00:00
        batchs[3].total_supply = 4444;
        batchs[3].total_sold = 0;
        batchs[3].price = 100000000000000; // wei
    }

    // update metadata uri per batch
    function updateMetadataUri(uint256 _batchId, string memory _uri)
        public
        onlyOwner
    {
        // check valid batch Id
        checkBatch(_batchId);

        // check current metadata uri
        bytes memory metadataUri = bytes(batchs[_batchId].metadataUri);
        require(metadataUri.length == 0, "Batch metadata uri already set.");

        batchs[_batchId].metadataUri = _uri;
    }

    // set random number for each batch
    function setRandomTokenUri(uint256 _batchId) public onlyOwner {
        // check current batch random number
        require(
            batchs[_batchId].randomNumber == 0,
            "Batch random number already set."
        );

        // has meet requirement
        require(
            canBatchReveal(_batchId),
            "Cannot set, batch must sold out, after 3 days and after release date"
        );

        // generate and set 1 random number from 1-10
        batchs[_batchId].randomNumber =
            (uint256(
                keccak256(
                    abi.encodePacked(block.timestamp, block.number, msg.sender)
                )
            ) % 10) +
            1;
    }

    // buy blind box
    // buyer will get token transaction only
    function buyBlindBox(
        uint256 _batchId // 1, 2 & 3
    ) public payable {
        // only buyer allow
        require(msg.sender != owner(), "Owner not allow to buy.");

        // check valid batch Id
        checkBatch(_batchId);

        //check release date
        require(
            block.timestamp >= batchs[_batchId].release_date,
            "Batch still not release yet."
        );

        //check stock
        require(
            batchs[_batchId].datetimeSoldOut == 0,
            "Character out of stock."
        );

        // minimum value allowed to be sent
        require(
            msg.value == batchs[_batchId].price,
            "Please enter the same price to continue your purchase."
        ); // in wei

        //update batch sold
        batchs[_batchId].total_sold += 1;

        //check sold out
        if (batchs[_batchId].total_supply == batchs[_batchId].total_sold) {
            // store datetime sold out by batch
            batchs[_batchId].datetimeSoldOut = block.timestamp;
        }

        //set a new token id for the token to be minted
        _tokenIdCounter.increment();
        uint256 tokenTransaction = _tokenIdCounter.current();

        // mapping data into buyerCollections
        buyerCollections memory buyerCollection = buyerCollections(
            _batchId,
            tokenTransaction,
            0,
            false
        );
        AllBuyerCollections[msg.sender].push(buyerCollection);
    }

    // check batch validation
    function checkBatch(uint256 _batchId) private pure {
        bool validBatch = false;
        if (_batchId != 1 || _batchId != 2 || _batchId != 3) {
            validBatch = true;
        }
        require(validBatch, "Batch Id not Valid.");
    }

    // get single collection by index (use myTotalCollections as reference)
    function myCollections(uint256 _index)
        public
        returns (
            uint256,
            uint256,
            uint256,
            bool
        )
    {
        // check collection based on address
        require(myTotalCollections() > 0, "No purchase record.");

        // check index
        require(myTotalCollections() > _index, "Index is invalid.");

        //update uri, if batch has sold out, batch has release and 3 days after sold out
        if (
            AllBuyerCollections[msg.sender][_index].reveal == false && // check existing tokenUri
            canBatchReveal(AllBuyerCollections[msg.sender][_index].batchId)
        ) {
            //check reveal requirement
            // set tokenUri - refer the index data in batch metadata
            AllBuyerCollections[msg.sender][_index]
                .tokenUri = getRandomTokenUri(
                AllBuyerCollections[msg.sender][_index].batchId,
                AllBuyerCollections[msg.sender][_index].tokenTransaction
            );

            //update to reveal - mark as reveal
            AllBuyerCollections[msg.sender][_index].reveal = true;
        }

        return (
            AllBuyerCollections[msg.sender][_index].batchId,
            AllBuyerCollections[msg.sender][_index].tokenTransaction,
            AllBuyerCollections[msg.sender][_index].tokenUri,
            AllBuyerCollections[msg.sender][_index].reveal
        );
    }

    // get total collection
    function myTotalCollections() public view returns (uint256) {
        return AllBuyerCollections[msg.sender].length;
    }

    //generate random number based on token transaction
    function getRandomTokenUri(uint256 _batchId, uint256 _tokenTransction)
        private
        view
        returns (uint256)
    {
        return
            (_tokenTransction + batchs[_batchId].randomNumber) %
            batchs[_batchId].total_supply;
    }

    // check requirement batch reveal - must sold out, after 3 days and after release date
    function canBatchReveal(uint256 _batchId) private view returns (bool) {
        uint256 delayDays = 3 days; // 1209600 or 2*7*24*60*60
        uint256 dateCooldown = batchs[_batchId].datetimeSoldOut + delayDays;

        if (
            batchs[_batchId].datetimeSoldOut != 0 && //check sold out
            block.timestamp >= dateCooldown
        ) {
            //check cooldown days
            return true;
        }
        return false;
    }

    // returning the contract's balance in wei
    function getContractBalance() public view onlyOwner returns (uint256) {
        return address(this).balance;
    }

    //tranfer eth from contract to owner
    function ownerWithdraw() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
