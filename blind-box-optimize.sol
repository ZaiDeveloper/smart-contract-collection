// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "hardhat/console.sol";

contract NftBlinkBox is ERC721, ERC721URIStorage, Ownable {
    // unique token counter
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    // store batch details
    struct batch {
        uint16 release_date; //timestamp
        uint8 total_supply;
        uint8 total_sold;
        uint256 price; // in wei
        uint16 datetimeSoldOut; // If all characters have been sold. (timestamp)
        string thumbnailUri;
        string metadataUri;
        uint8 randomNumber;
    }
    mapping(uint8 => batch) public batchs; // uint8 - batch id

    //set constructor
    constructor() ERC721("My Blind Box - Zai Zainal", "MBB") {}

    // add batch
    function addBatch(
        uint8 _batchId,
        uint16 _releaseDate,
        uint8 _totalSupply,
        uint256 _price,
        string memory _thumbnailUri,
        string memory _metadataUri
    ) public onlyOwner {
        // check existing batch
        require(batchs[_batchId].total_supply == 0, "Has set.");

        batchs[_batchId].release_date = _releaseDate; //Wednesday, 22 June 2022 00:00:00
        batchs[_batchId].total_supply = _totalSupply;
        batchs[_batchId].total_sold = 0;
        batchs[_batchId].price = _price; // wei
        batchs[_batchId].thumbnailUri = _thumbnailUri;
        batchs[_batchId].metadataUri = _metadataUri;
    }

    // set reveal random number for each batch
    function setReveal(uint8 _batchId) public onlyOwner {
        // check current batch random number
        require(batchs[_batchId].randomNumber == 0, "Has set.");

        // has meet requirement
        uint256 delayDays = 3 days; // 1209600 or 2*7*24*60*60
        require(
            batchs[_batchId].datetimeSoldOut != 0 && //check sold out
                block.timestamp >=
                (batchs[_batchId].datetimeSoldOut + delayDays),
            "must 3 days after sold out."
        );

        // generate and set 1 random number from 1-10
        batchs[_batchId].randomNumber = uint8(
            (uint256(
                keccak256(
                    abi.encodePacked(block.timestamp, block.number, msg.sender)
                )
            ) % 10) + 1
        );
    }

    // buy blind box
    // buyer will get token transaction only
    function buyBlindBox(
        uint8 _batchId // 1, 2 & 3
    ) public payable {
        // only buyer allow
        require(msg.sender != owner(), "Owner not allow.");

        // check valid batch Id
        require(
            _batchId != 1 || _batchId != 2 || _batchId != 3,
            "Batch Id not valid."
        );

        //check release date
        require(
            block.timestamp >= batchs[_batchId].release_date,
            "Not release yet."
        );

        //check stock - comment if u want testing
        require(batchs[_batchId].datetimeSoldOut == 0, "Out of stock.");

        // minimum value allowed to be sent
        require(msg.value == batchs[_batchId].price, "Invalid price."); // in wei

        //update batch sold
        batchs[_batchId].total_sold += 1;

        //check sold out
        if (batchs[_batchId].total_supply == batchs[_batchId].total_sold) {
            // store datetime sold out by batch
            batchs[_batchId].datetimeSoldOut = uint16(block.timestamp);
        }

        //set a new token id for the token to be minted
        _tokenIdCounter.increment();
        uint256 tokenID = _tokenIdCounter.current();
        _safeMint(msg.sender, tokenID); //mint the token
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    // return uri with random index based on token ID
    function tokenURI(uint256 _tokenID)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        uint8 batchId = getBatch(_tokenID);

        // check current metadata
        require(
            bytes(batchs[batchId].metadataUri).length > 0,
            "Metadata is null"
        );

        // if reveal not set yet, return batch thumnail
        if (batchs[batchId].randomNumber == 0) {
            // return thumnail image
            return batchs[batchId].thumbnailUri;
        }

        return
            string(
                abi.encodePacked(
                    batchs[batchId].metadataUri,
                    "/",
                    Strings.toString(
                        ((_tokenID + batchs[batchId].randomNumber) %
                            batchs[batchId].total_supply) + 1
                    )
                )
            );
    }

    // get batch based on token ID
    function getBatch(uint256 _tokenID) private view returns (uint8) {
        require(_exists(_tokenID), "Token ID not exist.");

        if (_tokenID <= 1111) {
            return 1;
        } else if (_tokenID > 1111 && _tokenID <= 2222) {
            return 2;
        }
        return 3;
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
